---
title: "Build a Spam Filter"
description: "Create a production-ready email spam classifier with training, persistence, and evaluation."
difficulty: beginner
classifiers: [bayes]
order: 2
---

# Build a Spam Filter

In this tutorial, you'll build a complete email spam filter that can be trained, saved, and used in production.

## What You'll Learn

- Training a classifier with real data
- Saving and loading trained models
- Evaluating classifier accuracy
- Handling edge cases

## Project Setup

Create a new directory for your project:

```bash
mkdir spam_filter
cd spam_filter
```

Create a `Gemfile`:

```ruby
source 'https://rubygems.org'

gem 'classifier'
```

Install dependencies:

```bash
bundle install
```

## Building the Spam Filter

Create `spam_filter.rb`:

```ruby
require 'classifier'

class SpamFilter
  def initialize
    @classifier = Classifier::Bayes.new 'Spam', 'Ham'
  end

  def train_spam(text)
    @classifier.train(spam: text)
  end

  def train_ham(text)
    @classifier.train(ham: text)
  end

  def spam?(text)
    @classifier.classify(text) == 'Spam'
  end

  def confidence(text)
    scores = @classifier.classifications(text)
    spam_score = scores['Spam']
    ham_score = scores['Ham']

    # Convert log probabilities to a confidence percentage
    total = Math.exp(spam_score) + Math.exp(ham_score)
    spam_probability = Math.exp(spam_score) / total
    spam_probability * 100
  end

  def save(path)
    @classifier.storage = Classifier::Storage::File.new(path: path)
    @classifier.save
  end

  def self.load(path)
    filter = new
    storage = Classifier::Storage::File.new(path: path)
    filter.instance_variable_set(:@classifier, Classifier::Bayes.load(storage: storage))
    filter
  end
end
```

## Training the Filter

Create `train.rb`:

```ruby
require_relative 'spam_filter'

filter = SpamFilter.new

# Spam examples
spam_examples = [
  "Congratulations! You've won $1,000,000!",
  "Click here to claim your free iPhone",
  "Buy cheap medications online now",
  "You have been selected for a special offer",
  "Make money fast working from home",
  "Limited time offer - act now!",
  "Your account has been compromised, click here",
  "Hot singles in your area want to meet you",
]

# Ham (legitimate) examples
ham_examples = [
  "Meeting scheduled for tomorrow at 2pm",
  "Please review the quarterly report attached",
  "Thanks for your help with the project",
  "Can you send me the latest version?",
  "The deployment was successful",
  "Happy birthday! Hope you have a great day",
  "Reminder: dentist appointment on Friday",
  "Your order has shipped and will arrive Monday",
]

# Train the classifier
spam_examples.each { |text| filter.train_spam(text) }
ham_examples.each { |text| filter.train_ham(text) }

# Save the trained model
filter.save('spam_filter.json')

puts "Training complete! Model saved to spam_filter.json"
```

## Using the Filter

Create `classify.rb`:

```ruby
require_relative 'spam_filter'

# Load the trained model
filter = SpamFilter.load('spam_filter.json')

# Test some emails
test_emails = [
  "You've won a free vacation!",
  "Team standup moved to 3pm",
  "Claim your prize now - limited time",
  "Invoice attached for your review",
]

test_emails.each do |email|
  verdict = filter.spam?(email) ? "SPAM" : "HAM"
  confidence = filter.confidence(email).round(1)
  puts "[#{verdict}] (#{confidence}% spam) #{email}"
end
```

Run training first, then classification:

```bash
ruby train.rb
ruby classify.rb
```

Output:
```
[SPAM] (95.5% spam) You've won a free vacation!
[HAM] (43.1% spam) Team standup moved to 3pm
[SPAM] (93.4% spam) Claim your prize now - limited time
[HAM] (13.6% spam) Invoice attached for your review
```

## Evaluating Accuracy

Create `evaluate.rb` to measure how well your filter performs:

```ruby
require_relative 'spam_filter'

filter = SpamFilter.load('spam_filter.json')

# Test dataset (keep separate from training data!)
test_data = [
  { text: "Get rich quick with this one weird trick", expected: :spam },
  { text: "Project deadline extended to next week", expected: :ham },
  { text: "Free trial - no credit card required", expected: :spam },
  { text: "Your package is out for delivery", expected: :ham },
]

correct = 0
test_data.each do |item|
  predicted = filter.spam?(item[:text]) ? :spam : :ham
  if predicted == item[:expected]
    correct += 1
    puts "✓ Correctly classified: #{item[:text][0..40]}..."
  else
    puts "✗ Misclassified: #{item[:text][0..40]}..."
  end
end

accuracy = (correct.to_f / test_data.length * 100).round(1)
puts "\nAccuracy: #{accuracy}%"
```

## Best Practices

1. **Use more training data**: The examples above are minimal. Real spam filters train on thousands of examples.

2. **Balance your categories**: Train with roughly equal amounts of spam and ham.

3. **Retrain periodically**: Spam evolves. Update your training data regularly.

4. **Handle uncertainty**: Consider a "maybe spam" category for borderline cases:

```ruby
def classify_with_confidence(text, threshold: 70)
  confidence = confidence(text)
  if confidence > threshold
    :spam
  elsif confidence < (100 - threshold)
    :ham
  else
    :uncertain
  end
end
```

## Next Steps

- [Document Categorizer](/docs/tutorials/document-classifier) - Classify documents into multiple categories
- [Save and Load Models](/docs/guides/persistence/basics) - Production persistence strategies
- [Performance Tuning](/docs/guides/production/performance) - Optimize for high-volume classification
