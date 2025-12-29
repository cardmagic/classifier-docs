---
title: "Logistic Regression Basics"
description: "Learn how the Logistic Regression classifier works for accurate, well-calibrated text classification."
category: logisticregression
order: 1
---

# Logistic Regression Classification

The Logistic Regression classifier uses gradient descent to learn discriminative decision boundaries between categories. It produces well-calibrated probabilities that always sum to 1.0, making it ideal for confidence-based decision making.

## How It Works

Logistic Regression classification works in three steps:

1. **Training**: Accumulate training examples with their word features
2. **Fitting**: Use Stochastic Gradient Descent (SGD) to learn optimal weights
3. **Classification**: Apply learned weights and softmax to get probabilities

### The Math (Simplified)

For a document with words and a category `C`, the score is:

```
score(C) = bias(C) + Σ(weight(C, word) × count(word))
```

Scores are converted to probabilities using the softmax function:

```
P(C) = exp(score(C)) / Σ exp(score(all categories))
```

This ensures probabilities are always between 0 and 1 and sum to 1.0.

## Creating a Classifier

```ruby
require 'classifier'

# Create with two or more categories
classifier = Classifier::LogisticRegression.new([:spam, :ham])

# With custom hyperparameters
classifier = Classifier::LogisticRegression.new(
  [:spam, :ham],
  learning_rate: 0.1,      # Step size for gradient descent
  regularization: 0.01,    # L2 regularization strength
  max_iterations: 100,     # Maximum training iterations
  tolerance: 1e-4          # Convergence threshold
)
```

## Training

Train the classifier by providing examples for each category:

```ruby
# Keyword arguments (recommended)
classifier.train(spam: 'Buy cheap viagra now!!!')
classifier.train(ham: 'Meeting tomorrow at 3pm')

# Batch training with arrays
classifier.train(
  spam: ['You won $1M!', 'Free money instantly'],
  ham: ['Project update', 'Lunch tomorrow?']
)

# Legacy APIs (still work)
classifier.train :spam, 'Click here for free stuff'
classifier.train_spam 'Limited time offer!'

# Stream training for large datasets
classifier.train_from_stream(:spam, File.open('spam_corpus.txt'), batch_size: 500)
```

### Lazy Fitting

The model is **not fitted during training**. It automatically fits when you first call `classify` or `probabilities`. You can also fit manually:

```ruby
# Manual fitting (optional)
classifier.fit

# Check if fitted
classifier.fitted?  # => true
```

## Classification

```ruby
# Get the best category
result = classifier.classify 'Claim your free prize now'
# => "Spam"

# Get well-calibrated probabilities (always sum to 1.0)
probs = classifier.probabilities 'Limited time offer'
# => {"Spam" => 0.92, "Ham" => 0.08}

# Get raw log-odds scores
scores = classifier.classifications 'Quarterly review scheduled'
# => {"Spam" => -2.1, "Ham" => 1.4}
```

### Understanding Probabilities

Unlike Naive Bayes, Logistic Regression produces **true probabilities**:
- Values are always between 0 and 1
- All probabilities sum to exactly 1.0
- Well-calibrated: if the model says 80% confidence, it's right ~80% of the time

This makes threshold-based decisions reliable:

```ruby
probs = classifier.probabilities(email_text)

if probs['Spam'] > 0.95
  # High confidence - auto-filter
  move_to_spam(email)
elsif probs['Spam'] > 0.5
  # Medium confidence - flag for review
  flag_for_review(email)
else
  # Low confidence - deliver normally
  deliver(email)
end
```

## Feature Weights

Inspect which words are most predictive for each category:

```ruby
# Get all weights for a category (sorted by importance)
weights = classifier.weights(:spam)
# => {:free => 2.3, :buy => 1.8, :money => 1.5, :meeting => -1.2, ...}

# Get top 10 most important features
top_features = classifier.weights(:spam, limit: 10)
```

Weight interpretation:
- **Positive weights**: Features that support this category
- **Negative weights**: Features that contradict this category
- **Higher absolute value**: More predictive power

## When to Use Logistic Regression

**Good for:**
- When you need well-calibrated probabilities
- Confidence-based decision making (threshold filtering)
- When interpretability matters (inspectable weights)
- Multi-class classification
- When accuracy is more important than training speed

**Not ideal for:**
- Incremental training (requires re-fitting for new data)
- Very large vocabularies (memory for weight matrix)
- When you need untraining support (use [Bayes](/docs/guides/bayes/basics))
- Semantic similarity (use [LSI](/docs/guides/lsi/basics))

## Comparison with Other Classifiers

| Feature | Logistic Regression | Naive Bayes | kNN |
|---------|---------------------|-------------|-----|
| **Training** | Batch (accumulate then fit) | Incremental | Instance-based |
| **Probabilities** | Well-calibrated (sum to 1.0) | Log probabilities | Confidence scores |
| **Untraining** | Not supported | Supported | Remove instances |
| **Speed** | Slower training, fast inference | Very fast | Slow inference |
| **Interpretability** | Feature weights | Word frequencies | Similar neighbors |

## Multi-Class Classification

Logistic Regression handles multiple categories naturally:

```ruby
classifier = Classifier::LogisticRegression.new(
  [:tech, :sports, :politics, :entertainment]
)

classifier.train(
  tech: ['New iPhone announced', 'Python 4.0 released'],
  sports: ['Lakers win championship', 'World Cup finals'],
  politics: ['Senate passes bill', 'Election results'],
  entertainment: ['Oscar nominations', 'New movie premiere']
)

probs = classifier.probabilities 'Breaking: Major tech company IPO'
# => {"Tech" => 0.72, "Sports" => 0.05, "Politics" => 0.15, "Entertainment" => 0.08}
```

## Thread Safety

The classifier is thread-safe for concurrent access:

```ruby
# Safe to classify from multiple threads
threads = 10.times.map do |i|
  Thread.new do
    result = classifier.classify(texts[i])
  end
end
threads.each(&:join)
```

## Streaming & Batch Training

For large datasets, use batch training with progress callbacks:

```ruby
classifier = Classifier::LogisticRegression.new([:spam, :ham])

# Batch training with progress tracking
classifier.train_batch(:spam, spam_documents, batch_size: 1000) do |progress|
  puts "#{progress.percent}% complete (#{progress.rate.round} docs/sec)"
end

# Train multiple categories at once
classifier.train_batch(
  spam: spam_documents,
  ham: ham_documents,
  batch_size: 500
) do |progress|
  puts "Processed #{progress.completed} documents"
end

# IMPORTANT: Must fit after batch training
classifier.fit
```

For files too large to load into memory, stream line-by-line:

```ruby
File.open('spam_corpus.txt', 'r') do |file|
  classifier.train_from_stream(:spam, file, batch_size: 1000) do |progress|
    puts "Processed #{progress.completed} lines"
  end
end

File.open('ham_corpus.txt', 'r') do |file|
  classifier.train_from_stream(:ham, file, batch_size: 1000)
end

# Always call fit() after streaming training
classifier.fit
```

Unlike Bayes, Logistic Regression accumulates training data during streaming and only trains the model when you call `fit()`. This makes it efficient for large datasets but means you must explicitly fit before classification.

See the [Streaming Training Tutorial](/docs/tutorials/streaming-training) for checkpoints and resumable training.

## Example: Spam Filter with Confidence Levels

```ruby
spam_filter = Classifier::LogisticRegression.new([:spam, :ham])

# Train with examples
spam_filter.train(
  spam: [
    'Buy cheap viagra now!!!',
    'You won $1 million dollars!',
    'Click here for free iPhone',
    'Limited time offer - act now!'
  ],
  ham: [
    'Meeting tomorrow at 3pm',
    'Quarterly report attached',
    'Can you review this document?',
    'Lunch next week?'
  ]
)

# Classify with confidence-based handling
def process_email(email)
  probs = spam_filter.probabilities(email.body)

  case
  when probs['Spam'] > 0.95
    { action: :delete, reason: 'High confidence spam' }
  when probs['Spam'] > 0.7
    { action: :quarantine, reason: 'Likely spam' }
  when probs['Spam'] > 0.4
    { action: :flag, reason: 'Suspicious content' }
  else
    { action: :deliver, reason: 'Appears legitimate' }
  end
end

# Inspect what the model learned
puts "Top spam indicators:"
spam_filter.weights(:spam, limit: 5).each do |word, weight|
  puts "  #{word}: #{weight.round(2)}"
end
```

## Next Steps

- [Streaming Training](/docs/tutorials/streaming-training) - Train on large datasets with progress tracking
- [Persistence](/docs/guides/persistence/basics) - Save and load trained classifiers
- [Real-time Pipeline](/docs/tutorials/realtime-pipeline) - Build a production-ready classification pipeline
