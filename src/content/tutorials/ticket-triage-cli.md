---
title: "Triage Tickets from the Shell"
description: "Sort a folder of support tickets into categories with the classifier and keywords commands, without writing any Ruby."
difficulty: beginner
classifiers: ["bayes", "tfidf"]
order: 6
---

# Triage Tickets from the Shell

Every other tutorial here writes Ruby. This one writes none. You will train a
classifier, sort a folder of support tickets into categories, and see why each
ticket landed where it did, using only the two commands the gem installs.

This suits anyone who installed the tool with Homebrew and wants results before
committing to a Ruby project.

## What you need

```bash
gem install classifier
```

Or, with no Ruby project at all:

```bash
brew install classifier
```

Both commands come with it:

```bash
classifier --version
keywords --version
```

## The corpus

Make a folder per category, with one example ticket per line. Each line counts
as a separate document, so the line count is the training set size.

```bash
mkdir -p tickets/billing tickets/bug tickets/howto inbox
```

`tickets/billing/train.txt`:

```
I was charged twice for my subscription this month please refund
My invoice shows the wrong amount and I need a corrected receipt
Cancel my plan and stop billing my card immediately
The annual renewal charged before I could downgrade my account
I need a copy of the receipt for my expense report
Update the credit card on file for future payments
```

`tickets/bug/train.txt`:

```
The export button throws an error and nothing downloads
App crashes on launch after the latest update
Login fails with a blank screen on Safari only
Data is missing from the dashboard after the sync ran
Uploading a file freezes at ninety percent every time
The search results return duplicates for one query
```

`tickets/howto/train.txt`:

```
How do I invite a teammate to my workspace
Where can I change the notification settings for email
Is there a way to export my data as a spreadsheet
How do I reset my password without the recovery email
What is the difference between the pro and team plans
Can I schedule a report to send every Monday
```

## Step 1: Look at the corpus first

Before you train anything, ask what vocabulary you actually have. `keywords`
builds a TF-IDF model and reports it:

```console
$ keywords fit -m tickets.json tickets/*/train.txt
Saved to "/path/to/tickets.json"

$ keywords info -m tickets.json
Documents: 18
Vocabulary: 92
Min DF: 1
Max DF: 1.0
```

18 documents and 92 terms. That is small, and it is worth knowing now rather
than after a week of confusing results. Real work wants hundreds of examples
per category. This tutorial stays small so you can retype it.

## Step 2: Train the classifier

`classifier` keeps its own model, in its own file:

```bash
classifier -f triage.json train billing tickets/billing/train.txt
classifier -f triage.json train bug tickets/bug/train.txt
classifier -f triage.json train howto tickets/howto/train.txt
```

Check what it learned:

```console
$ classifier -f triage.json info
{
  "file": "triage.json",
  "type": "bayes",
  "categories": [
    "Billing",
    "Bug",
    "Howto"
  ],
```

Note the two flags. `classifier` takes `-f` and `keywords` takes `-m`. The
models are different formats and each command rejects the other's file.

## Step 3: Classify, and see the reason

Put three new tickets in `inbox/`:

```bash
echo 'The dashboard shows an error and the page will not load' > inbox/t1.txt
echo 'Please refund the duplicate charge on my invoice'        > inbox/t2.txt
echo 'How do I invite a colleague to the workspace'            > inbox/t3.txt
```

Run both commands over each one. The first gives the label, the second gives
the terms behind it:

```bash
for f in inbox/*.txt; do
  echo "--- $f"
  echo -n "  label: "; classifier -f triage.json "$(cat "$f")"
  echo -n "  terms: "; keywords -m tickets.json -n 3 "$(cat "$f")"
done
```

```
--- inbox/t1.txt
  label: bug
  terms: error:0.58 shows:0.58 dashboard:0.58
--- inbox/t2.txt
  label: billing
  terms: invoice:0.46 duplicate:0.46 refund:0.46
--- inbox/t3.txt
  label: howto
  terms: workspace:0.71 invite:0.71
```

All three are right, and the terms say why. `invoice`, `duplicate`, and
`refund` are exactly the words that should drive a billing ticket. When a
label surprises you, this second line is where you look first.

## Step 4: Sort the folder

The label is plain text on stdout, so a shell loop can file each ticket:

```bash
mkdir -p sorted
for f in inbox/*.txt; do
  label=$(classifier -f triage.json "$(cat "$f")")
  mkdir -p "sorted/$label"
  cp "$f" "sorted/$label/"
done

find sorted -type f | sort
```

```
sorted/billing/t2.txt
sorted/bug/t1.txt
sorted/howto/t3.txt
```

## Step 5: Send the doubtful ones to a human

Not every ticket is clear. Add a vague one and compare the probabilities with
`-p`:

```console
$ echo 'I cannot get the thing to work properly' > inbox/vague.txt

$ classifier -f triage.json -p "$(cat inbox/vague.txt)"
billing:0.27 bug:0.31 howto:0.42

$ classifier -f triage.json -p "$(cat inbox/t2.txt)"
billing:0.86 bug:0.08 howto:0.06
```

The clear ticket wins at 0.86. The vague one tops out at 0.42, with the other
two categories close behind. A near-even spread means the classifier is
guessing.

Route on that number rather than trusting every label:

```bash
for f in inbox/*.txt; do
  top=$(classifier -f triage.json -p "$(cat "$f")" | tr ' ' '\n' | cut -d: -f2 | sort -rn | head -1)
  label=$(classifier -f triage.json "$(cat "$f")")

  if [ "$(echo "$top >= 0.6" | bc -l)" = "1" ]; then
    echo "$(basename "$f") -> $label (auto, $top)"
  else
    echo "$(basename "$f") -> review queue (top score only $top)"
  fi
done
```

```
t2.txt -> billing (auto, 0.86)
vague.txt -> review queue (top score only 0.42)
```

Pick the threshold from your own data. Start near 0.6, watch what lands in the
review queue, and move it.

## Retraining

`classifier train` adds to the existing model rather than replacing it. To
start over, delete the file:

```bash
rm triage.json
```

Refit the `keywords` vocabulary whenever the corpus changes, so the
explanations keep matching the training data:

```bash
keywords fit -m tickets.json tickets/*/train.txt
```

## What to do next

- Add real tickets until each category holds a few hundred lines. Small
  corpora produce confident nonsense.
- Watch the review queue. Tickets that land there repeatedly are usually a
  category you have not created yet.
- Run `keywords info` after each corpus change. A vocabulary that grows much
  faster than the document count often means noise, such as pasted logs or
  signatures.

## Next Steps

- [CLI Basics](/docs/guides/cli/basics) - Every command and option
- [Spam Filter](/docs/tutorials/spam-filter) - The same idea in Ruby
- [Bayes Basics](/docs/guides/bayes/basics) - How the classifier decides
