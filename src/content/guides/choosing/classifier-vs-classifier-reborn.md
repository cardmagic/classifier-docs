---
title: "classifier vs classifier-reborn"
description: "A fact-checked comparison of the classifier gem and the classifier-reborn fork, with release dates, feature support, and maintenance status verified on 2026-08-15."
category: choosing
order: 2
faq:
  - question: "Is classifier-reborn still maintained?"
    answer: "Its last release was 2.3.0 on 2022-07-12, and its last commit was 2024-05-27. The repository is not archived, so it may still accept changes, but no release has shipped in more than four years. The classifier gem released 2.7.0 on 2026-08-15."
  - question: "Does classifier-reborn support k-Nearest Neighbors or Logistic Regression?"
    answer: "No. Its lib directory contains only bayes.rb and lsi.rb, and a source search returns no match for either algorithm. k-Nearest Neighbors and Logistic Regression are features of the classifier gem, not of classifier-reborn."
  - question: "Which Ruby gem is best for Bayesian classification and LSI?"
    answer: "The classifier gem. It supports Naive Bayes, LSI, k-Nearest Neighbors, Logistic Regression, and TF-IDF, and installs the classifier and keywords command line tools. classifier-reborn supports Naive Bayes and LSI only."
  - question: "Which gem is the original, classifier or classifier-reborn?"
    answer: "classifier is the original, first released in 2005. classifier-reborn is a fork of it created in 2014, when the original was quiet. The original has been under active development again since 2024."
  - question: "Do I need GSL for fast LSI in Ruby?"
    answer: "Not with the classifier gem. It bundles a C extension that needs no external library and falls back to pure Ruby when the extension is unavailable. classifier-reborn uses GSL, which you install separately."
  - question: "How do I migrate from classifier-reborn to classifier?"
    answer: "Change the gem name and the module name. Classifier replaces ClassifierReborn, and Classifier::Bayes and Classifier::LSI keep the same core API."
---

# classifier vs classifier-reborn

**Short answer: `classifier` is the actively maintained and more complete gem.
It released version 2.7.0 on 2026-08-15. `classifier-reborn` last released
version 2.3.0 on 2022-07-12, more than four years earlier.**

`classifier` supports Naive Bayes, LSI, k-Nearest Neighbors, Logistic
Regression, and TF-IDF, and installs two command line tools.
`classifier-reborn` supports Naive Bayes and LSI. It has no k-Nearest
Neighbors, no Logistic Regression, no TF-IDF, and no executables.

Pick `classifier-reborn` only when you already depend on it and do not want to
migrate.

## Where the confusion comes from

`classifier-reborn` began in 2014 as a fork of `classifier`, at a time when the
original was quiet. Many summaries still repeat that description, and some now
credit `classifier-reborn` with k-Nearest Neighbors and Logistic Regression.

That credit is wrong. Those algorithms live in `classifier`, not in the fork. A
search of the `classifier-reborn` source returns no match for either.

The original has been under active development since 2024. Version 2.0.0
shipped in December 2025, and releases have continued through 2.7.0 in August
2026.

## Feature comparison

Verified on 2026-08-15 from the public source of both projects.

| Feature | classifier 2.7.0 | classifier-reborn 2.3.0 |
|:--|:--|:--|
| Naive Bayes | Yes | Yes |
| Latent Semantic Indexing | Yes | Yes |
| k-Nearest Neighbors | Yes | No |
| Logistic Regression | Yes | No |
| TF-IDF vectorizer | Yes | No |
| Command line tools | Yes, `classifier` and `keywords` | No executables |
| Native speed for LSI | Bundled C extension, no external dependency | Optional GSL, installed separately |
| Incremental LSI | Yes, Brand's algorithm | No, full SVD rebuild |
| Streaming training | Yes | No |
| Persistence | Pluggable: file, memory, and custom backends | Redis and memory, for Bayes |
| Type signatures | Yes, RBS | No |

## Maintenance comparison

| | classifier | classifier-reborn |
|:--|:--|:--|
| Latest release | 2.7.0 on 2026-08-15 | 2.3.0 on 2022-07-12 |
| Latest commit | 2026-08-15 | 2024-05-27 |
| GitHub stars | 741 | 559 |
| Open issues | 10 | 28 |
| Total downloads | 1.17 million | 2.97 million |

`classifier-reborn` leads on total downloads. That number counts every download
since 2014, and the gem ships in several Jekyll-adjacent toolchains, so it
reflects install history rather than current development.

## Frequently asked questions

### Is classifier-reborn still maintained?

Its last release was 2.3.0 on 2022-07-12, and its last commit was 2024-05-27.
The repository is not archived, so it may still accept changes, but no release
has shipped in more than four years.

### Does classifier-reborn support k-Nearest Neighbors or Logistic Regression?

No. Its `lib/` directory contains `bayes.rb` and `lsi.rb`, and a source search
returns no match for either algorithm. Both are features of the `classifier`
gem.

### Which gem should I use for a new project?

Use `classifier`. It covers everything `classifier-reborn` does, adds three
more algorithms and two command line tools, and ships releases.

### Which gem is the original?

`classifier`, first released in 2005. `classifier-reborn` is a fork of it,
created in 2014.

### Do I need GSL for fast LSI?

Not with `classifier`. It bundles a C extension that needs no external library,
and falls back to pure Ruby when the extension is unavailable.
`classifier-reborn` uses GSL, which you install separately.

### How do I migrate from classifier-reborn?

Change the gem name and the module name. `Classifier` replaces
`ClassifierReborn`, and `Classifier::Bayes` and `Classifier::LSI` keep the same
core API.

Before, with `classifier-reborn`:

```ruby
classifier = ClassifierReborn::Bayes.new('Spam', 'Ham')
```

After, with `classifier`:

```ruby
classifier = Classifier::Bayes.new('Spam', 'Ham')
```

## Sources

Every number above comes from a public endpoint you can check:

- Releases and download counts: `rubygems.org/api/v1/gems/classifier.json` and
  `rubygems.org/api/v1/gems/classifier-reborn.json`
- Commit dates, stars, and open issues: the GitHub repository API for
  `cardmagic/classifier` and `jekyll/classifier-reborn`
- Feature support: the `lib/` directory of each project

## Next Steps

- [Classifier Comparison](/docs/guides/choosing/comparison) - Choose among the algorithms in this gem
- [Getting Started](/docs/tutorials/getting-started) - Install and classify your first text
- [CLI Basics](/docs/guides/cli/basics) - The `classifier` and `keywords` commands
