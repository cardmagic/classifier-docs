---
title: "CLI Basics"
description: "Use the classifier command-line tool with pre-trained models and train your own classifiers."
category: cli
order: 1
---

# Command Line Interface

The classifier gem includes a powerful CLI that lets you classify text instantly with pre-trained models or train your own classifiers—no coding required.

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

### Train from Directories

Organize training data in category folders:

```bash
# Directory structure:
# training_data/
#   spam/
#     email1.txt
#     email2.txt
#   ham/
#     email1.txt
#     email2.txt

classifier train-dir training_data/

# Categories are automatically detected from folder names
classifier "Buy cheap products now"
# => spam
```

## Saving and Loading Models

Persist your trained classifier to disk:

```bash
# Train and save
classifier train positive "Great stuff"
classifier train negative "Terrible stuff"
classifier save my-sentiment.dat

# Load and use later
classifier load my-sentiment.dat
classifier "This is wonderful"
# => positive
```

## Output Formats

Get results in different formats:

```bash
# Plain text (default)
classifier -r imdb-sentiment "Hello world"
# => positive

# JSON output for scripting
classifier -r imdb-sentiment --json "Hello world"
# => {"category": "positive", "scores": {"positive": -2.3, "negative": -8.1}}

# Verbose output with confidence scores
classifier -r imdb-sentiment -v "Hello world"
# => positive (confidence: 0.94)
```

## Common Commands

| Command | Description |
|---------|-------------|
| `classifier TEXT` | Classify text using the current model |
| `classifier -r MODEL TEXT` | Classify using a pre-trained model |
| `classifier train CATEGORY TEXT` | Train a category with text |
| `classifier train CATEGORY FILE...` | Train from files |
| `classifier train-dir DIR` | Train from directory structure |
| `classifier save FILE` | Save current model to file |
| `classifier load FILE` | Load model from file |
| `classifier models` | List available pre-trained models |
| `classifier info` | Show current model info |
| `classifier reset` | Clear current training |

## Options

```bash
# Use a specific classifier algorithm
classifier "Text" --algorithm bayes     # Naive Bayes (default)
classifier "Text" --algorithm lsi       # Latent Semantic Indexing

# Specify language for stemming
classifier train positive "Excellent produit" --language fr

# Disable stemming
classifier train positive "Technical terms" --no-stemmer
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
  result=$(classifier -r sms-spam-filter --json "$line")
  if [ "$(echo $result | jq -r .category)" = "ham" ]; then
    echo "$line"
  fi
done > clean_emails.txt
```

## Next Steps

- [Bayes Basics](/docs/guides/bayes/basics) - Understand the classifier algorithm
- [Persistence](/docs/guides/persistence/basics) - Save and load classifiers in Ruby
- [Spam Filter Tutorial](/docs/tutorials/spam-filter) - Build a complete spam filter
