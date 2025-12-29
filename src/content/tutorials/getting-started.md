---
title: "Getting Started"
description: "Install the classifier gem and make your first classification in under 5 minutes."
difficulty: beginner
classifiers: [bayes]
order: 1
---

# Getting Started with Ruby Classifier

This tutorial will get you up and running with the classifier gem in under 5 minutes. By the end, you'll have a working text classifier.

## Prerequisites

- Ruby 2.7 or higher
- Bundler (optional, but recommended)

## Installation

Install the gem directly:

```bash
gem install classifier
```

Or add it to your Gemfile:

```ruby
gem 'classifier'
```

Then run:

```bash
bundle install
```

## Your First Classifier

Let's build a simple spam detector. Create a file called `spam_detector.rb`:

```ruby
require 'classifier'

# Create a classifier with two categories
classifier = Classifier::Bayes.new 'Spam', 'Ham'

# Train it with some examples
classifier.train(spam: "Get rich quick! Buy now!")
classifier.train(spam: "You've won a million dollars!")
classifier.train(spam: "Click here for free stuff")

classifier.train(ham: "Meeting tomorrow at 10am")
classifier.train(ham: "Please review the attached document")
classifier.train(ham: "Thanks for your email")

# Now classify some new text
puts classifier.classify "Claim your free prize today!"
# => "Spam"

puts classifier.classify "See you at the meeting"
# => "Ham"
```

Run it:

```bash
ruby spam_detector.rb
```

## Understanding the Output

The `classify` method returns the most likely category for the given text. Under the hood, the Bayesian classifier:

1. Tokenizes the text into words
2. Stems each word to its root form
3. Calculates the probability of each category
4. Returns the category with the highest probability

## Getting Probability Scores

Want to see the actual scores? Use `classifications`:

```ruby
scores = classifier.classifications "Limited time offer!"
puts scores
# => {"Spam" => -5.2, "Ham" => -9.8}
```

Higher (less negative) scores indicate higher probability. The classifier returns log probabilities to avoid numerical underflow with large datasets.

## Next Steps

Now that you have a basic classifier working, explore these topics:

- [Build a Complete Spam Filter](/docs/tutorials/spam-filter) - A production-ready email classifier
- [Bayes Basics Guide](/docs/guides/bayes/basics) - Deep dive into how Bayesian classification works
- [LSI for Semantic Search](/docs/guides/lsi/basics) - Find related documents using meaning, not just keywords
- [kNN Classification](/docs/guides/knn/basics) - Instance-based classification with interpretable results
- [TF-IDF Vectorizer](/docs/guides/tfidf/basics) - Transform text into weighted feature vectors

## Quick Reference

```ruby
# Create classifier
classifier = Classifier::Bayes.new 'Category1', 'Category2'

# Train with keyword arguments (recommended)
classifier.train(category1: "example text")

# Batch train with arrays
classifier.train(category1: ["text 1", "text 2"], category2: ["text 3"])

# Legacy APIs (still work)
classifier.train :Category1, "example text"
classifier.train_category1 "example text"

# Classify
result = classifier.classify "text to classify"

# Get scores
scores = classifier.classifications "text to classify"
```
