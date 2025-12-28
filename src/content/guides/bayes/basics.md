---
title: "Bayes Basics"
description: "Understand how the Bayesian classifier works and when to use it."
category: bayes
order: 1
---

# Bayesian Classification Basics

The Bayesian classifier uses Bayes' theorem to calculate the probability that a piece of text belongs to each category. It's simple, fast, and surprisingly effective for many text classification tasks.

## How It Works

Naive Bayes classification works in three steps:

1. **Training**: Count word frequencies for each category
2. **Classification**: Calculate probability of each category given the words
3. **Decision**: Return the category with highest probability

### The Math (Simplified)

For a document with words `w1, w2, w3`, the probability of category `C` is:

```
P(C | w1, w2, w3) ∝ P(C) × P(w1|C) × P(w2|C) × P(w3|C)
```

Where:
- `P(C)` is the prior probability of category C
- `P(w|C)` is the probability of seeing word w in category C

The "naive" assumption is that words are independent of each other, which isn't true but works well in practice.

## Creating a Classifier

```ruby
require 'classifier'

# Create with any number of categories
classifier = Classifier::Bayes.new 'Tech', 'Sports', 'Politics'
```

## Training

Train the classifier by providing examples for each category:

```ruby
# Keyword arguments (recommended)
classifier.train(tech: 'New JavaScript framework released')
classifier.train(sports: 'Team wins championship game')
classifier.train(politics: 'Senate passes new legislation')

# Batch training with arrays
classifier.train(
  tech: ['Apple announces new MacBook', 'Python 4.0 features announced'],
  sports: ['Soccer player signs new contract', 'Team wins finals']
)

# Legacy APIs (still work)
classifier.train :Tech, 'Example text'
classifier.train_tech 'Example text'
```

### Training Tips

1. **More data is better**: Accuracy improves significantly with more training examples
2. **Balance categories**: Try to provide similar amounts of data for each category
3. **Use representative examples**: Train with text similar to what you'll classify

## Classification

```ruby
# Get the best category
result = classifier.classify 'The new iPhone has amazing features'
# => "Tech"

# Get scores for all categories
scores = classifier.classifications 'Congress debates tax reform'
# => {"Tech" => -15.2, "Sports" => -18.4, "Politics" => -8.1}
```

### Understanding Scores

The classifier returns **log probabilities**:
- Scores are always negative
- Higher (less negative) = more likely
- Differences matter more than absolute values

To convert to relative probabilities:

```ruby
scores = classifier.classifications(text)

# Normalize to get percentages
max_score = scores.values.max
normalized = scores.transform_values { |s| Math.exp(s - max_score) }
total = normalized.values.sum
percentages = normalized.transform_values { |v| (v / total * 100).round(1) }
```

## When to Use Bayes

**Good for:**
- Spam detection
- Sentiment analysis (positive/negative)
- Topic categorization
- Language detection
- Any task with clear category boundaries

**Not ideal for:**
- Finding related documents (use [LSI](/docs/guides/lsi/basics) instead)
- Semantic similarity
- When word order matters significantly

## Configuration Options

```ruby
# Enable automatic stemming (on by default)
classifier = Classifier::Bayes.new :a, :b, enable_stemmer: true

# Use custom language for stemming
classifier = Classifier::Bayes.new :a, :b, language: 'fr'

# Disable threshold (classify everything, even low confidence)
classifier = Classifier::Bayes.new :a, :b, enable_threshold: false
```

## Example: Sentiment Analyzer

```ruby
sentiment = Classifier::Bayes.new 'Positive', 'Negative'

# Train with examples
sentiment.train(positive: "I love this product!")
sentiment.train(positive: "Excellent service, highly recommend")
sentiment.train(positive: "Best purchase I've ever made")

sentiment.train(negative: "Terrible experience, avoid")
sentiment.train(negative: "Waste of money")
sentiment.train(negative: "Disappointing and frustrating")

# Or batch train
sentiment.train(
  positive: ["Amazing quality!", "Highly recommended"],
  negative: ["Total disappointment", "Don't waste your money"]
)

# Classify new reviews
sentiment.classify "This is amazing!"
# => "Positive"

sentiment.classify "Complete garbage, don't buy"
# => "Negative"
```

## Next Steps

- [Training Strategies](/docs/guides/bayes/training) - Best practices for training data
- [Persistence](/docs/guides/persistence/basics) - Save and load trained classifiers
- [Performance](/docs/guides/production/performance) - Optimize for production use
