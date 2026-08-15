---
title: "CLI Basics"
description: "Use the classifier command-line tool with pre-trained models and train your own classifiers."
category: cli
order: 1
---

# Command Line Interface

The classifier gem includes a powerful CLI that lets you classify text instantly with pre-trained models or train your own classifiers. No code required.

## Installation

Install the classifier gem which includes the CLI:

```bash
gem install classifier
```

Or install via Homebrew for CLI-only usage:

```bash
brew install classifier
```

## Quick Start with Pre-trained Models

Classify text instantly using community-trained models:

```bash
# Detect spam
classifier -r sms-spam-filter "You won a free iPhone"
# => spam

# Analyze sentiment
classifier -r imdb-sentiment "This movie was absolutely amazing"
# => positive

# Detect emotions
classifier -r emotion-detection "I'm so happy today"
# => joy
```

List all available pre-trained models:

```bash
classifier models
```

## Training Your Own Classifier

Build a custom classifier by training on your own data:

### Train from Text

```bash
# Train the positive category
classifier train positive "I love this product"
classifier train positive "Excellent quality, highly recommend"

# Train the negative category
classifier train negative "Terrible experience"
classifier train negative "Complete waste of money"

# Classify new text
classifier "This is amazing"
# => positive
```

### Train from Files

For larger datasets, train from text files:

```bash
# Train from individual files
classifier train positive reviews/good/*.txt
classifier train negative reviews/bad/*.txt

# Classify new text
classifier "Great product, highly recommend"
# => positive
```

## Model Files

The CLI automatically saves your trained model to `./classifier.json`. Use the `-f` flag to specify a different file:

```bash
# Train and save to custom file
classifier -f my-sentiment.json train positive "Great stuff"
classifier -f my-sentiment.json train negative "Terrible stuff"

# Use the model later
classifier -f my-sentiment.json "This is wonderful"
# => positive
```

## Showing Probabilities

Use `-p` to see probability scores:

```bash
classifier -r imdb-sentiment -p "Hello world"
# => positive (0.94)
```

## Commands

| Command | Description |
|---------|-------------|
| `classifier TEXT` | Classify text using the current model |
| `classifier -r MODEL TEXT` | Classify using a remote model |
| `classifier train CATEGORY [FILES...]` | Train a category from files or stdin |
| `classifier info` | Show model information |
| `classifier fit` | Fit the model (logistic regression) |
| `classifier search QUERY` | Semantic search (LSI only) |
| `classifier related ITEM` | Find related documents (LSI only) |
| `classifier models` | List models in registry |
| `classifier pull MODEL` | Download model from registry |
| `classifier push FILE` | Contribute model to registry |

## Options

```bash
# Model file (default: ./classifier.json)
classifier -f my-model.json "Text"

# Classifier type
classifier -m bayes "Text"    # Naive Bayes (default)
classifier -m lsi "Text"      # Latent Semantic Indexing
classifier -m knn "Text"      # K-Nearest Neighbors
classifier -m lr "Text"       # Logistic Regression

# Show probabilities
classifier -p "Text"

# KNN options
classifier -m knn -k 10 "Text"           # Number of neighbors
classifier -m knn --weighted "Text"      # Distance-weighted voting

# Logistic regression options
classifier -m lr --learning-rate 0.01 --max-iterations 200 "Text"

# Quiet mode
classifier -q "Text"
```

## Piping and Scripting

The CLI works well in Unix pipelines:

```bash
# Classify from stdin
echo "This product is amazing" | classifier -r imdb-sentiment

# Batch classify a file
cat reviews.txt | while read line; do
  classifier -r imdb-sentiment "$line"
done

# Filter spam from a file
cat emails.txt | while read line; do
  result=$(classifier -r sms-spam-filter "$line")
  if [ "$result" = "ham" ]; then
    echo "$line"
  fi
done > clean_emails.txt
```

## The keywords Command

The gem installs a second command, `keywords`. It scores the terms of a text
with TF-IDF and prints `term:score` pairs in descending order of score.

Unlike `classifier`, it ships no pre-trained models, so build a vocabulary
first. Every later command reads that model:

```bash
# Each line of each file becomes a separate document
keywords fit corpus/*.txt
# => Saved to "/path/to/keywords.json"
```

Then score any text:

```bash
# Score a raw string
keywords "Ruby is a programming language"
# => language:0.58 programming:0.58 ruby:0.58

# Score a file
keywords extract article.txt

# Pipe from stdin
curl -s https://example.com/article | keywords extract

# Top 5 terms only
keywords -n 5 "long document with many terms..."
```

Inspect the model:

```bash
keywords info
# => Documents: 1,234
# => Vocabulary: 5,678
# => Min DF: 1
# => Max DF: 1.0
```

Tune the vocabulary during the fit:

```bash
keywords fit --min-df 2 --max-df 0.85 --ngram 1,2 corpus/*.txt
```

`--min-df` drops a term that too few documents hold, `--max-df` drops a term
that too many hold, and `--ngram MIN,MAX` indexes phrases as well as single
words. An n-gram label joins its parts with a space, as in
`machine learning:0.35`, so parse the output on the `:` separator rather than
on whitespace.

Output maps stems back to whole words, so a model built from `programming`
prints `programming`, not `program`.

### keywords options

| Option | Meaning |
|--------|---------|
| `-m`, `--model FILE` | Model file (default: `./keywords.json`) |
| `-n`, `--top N` | Print the top N terms only |
| `-q` | Suppress the `Saved to` line from `fit` |
| `--min-df N` | Minimum document frequency, as a count |
| `--max-df N` | Maximum document frequency ratio, 0.0 to 1.0 |
| `--ngram MIN,MAX` | N-gram range (default: `1,1`) |

A usage error exits 2 and any other error exits 1, so a script can tell the two
apart:

```bash
keywords fit corpus/*.txt || echo "fit failed with $?"
```

## Next Steps

- [Bayes Basics](/docs/guides/bayes/basics) - Understand the classifier algorithm
- [TF-IDF Basics](/docs/guides/tfidf/basics) - The vectorizer behind `keywords`
- [Persistence](/docs/guides/persistence/basics) - Save and load classifiers in Ruby
- [Spam Filter Tutorial](/docs/tutorials/spam-filter) - Build a complete spam filter
