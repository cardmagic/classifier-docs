---
title: "kNN Basics"
description: "Instance-based classification with k-Nearest Neighbors for interpretable results."
category: knn
order: 1
---

# k-Nearest Neighbors Basics

k-Nearest Neighbors (kNN) is an instance-based classifier that stores examples and classifies new text by finding the most similar ones. Unlike Bayes, there's no training phase—just add examples and classify.

## How It Works

1. **Store examples**: Each example is stored with its category
2. **Find neighbors**: For new text, find the k most similar stored examples
3. **Vote**: The category with the most neighbors wins

kNN uses LSI under the hood for semantic similarity, so "dog" and "puppy" are recognized as related.

## Creating a Classifier

```ruby
require 'classifier'

knn = Classifier::KNN.new(k: 3)  # Use 3 nearest neighbors
```

## Adding Examples

kNN supports two equivalent methods for adding labeled examples: `train` (consistent with Bayes and LogisticRegression) and `add` (kNN-specific terminology).

```ruby
# Using train (consistent API across all classifiers)
knn.train(spam: "Buy now! Limited offer!")
knn.train(ham: "Meeting tomorrow at 3pm")

# Using add (equivalent, kNN-specific terminology)
knn.add(spam: "Buy now! Limited offer!")
knn.add(ham: "Meeting tomorrow at 3pm")

# Dynamic train methods (like Bayes)
knn.train_spam "You've won a million dollars!"
knn.train_ham "Thanks for your email"

# Add multiple examples at once
knn.train(
  spam: ["Click here for free stuff", "Limited time offer!"],
  ham: ["Please review the document", "See you tomorrow"]
)
```

The `train` method is an alias for `add`, so they work identically. Use `train` when you want consistent code that works with any classifier type.

## Classification

```ruby
# Get the best category
result = knn.classify "Congratulations! Claim your prize!"
# => "spam"

# Get detailed results with neighbors
result = knn.classify_with_neighbors "Free money offer"

result[:category]    # => "spam"
result[:confidence]  # => 0.85
result[:neighbors]   # => [{item: "Buy now!...", category: "spam", similarity: 0.92}, ...]
result[:votes]       # => {"spam" => 2.0, "ham" => 1.0}
```

## Distance-Weighted Voting

By default, each neighbor gets one vote. With weighted voting, closer neighbors have more influence:

```ruby
knn = Classifier::KNN.new(k: 5, weighted: true)

knn.add(
  positive: ["Great product!", "Loved it!", "Excellent service"],
  negative: ["Terrible experience", "Would not recommend"]
)

# Closer neighbors influence the result more
knn.classify "This was amazing!"
# => "positive"
```

## Updating the Classifier

```ruby
# Add more examples anytime
knn.add(neutral: "It was okay, nothing special")

# Remove specific examples
knn.remove_item "Buy now! Limited offer!"

# Adjust k
knn.k = 7

# List all categories
knn.categories
# => ["spam", "ham", "neutral"]
```

## When to Use kNN

**Good for:**
- Small to medium datasets (<1000 examples)
- When you need interpretable results (see which examples influenced the decision)
- Incremental learning (easy to add/remove examples)
- Multi-label classification

**Not ideal for:**
- Large datasets (stores all examples, compares against all during classification)
- When speed is critical
- Very high-dimensional feature spaces

## kNN vs Bayes vs LSI

| Feature | kNN | Bayes | LSI |
|---------|-----|-------|-----|
| Storage | All examples | Word counts only | All examples |
| Best size | <1000 examples | Any size | <1000 documents |
| Interpretable | Yes (see neighbors) | No | No |
| Speed | Slower | Very fast | Medium |

**Why the size difference?** Bayes stores aggregate statistics—adding 10,000 documents just increments counters. kNN stores every example and compares against all of them during classification.

## Choosing k

- **Small k (3-5)**: More sensitive to noise, but captures local patterns
- **Large k (10+)**: More stable, but may miss subtle distinctions
- **Rule of thumb**: Start with k = sqrt(n) where n is your dataset size
- **Odd k**: Avoids ties in binary classification

## Example: Product Review Classifier

```ruby
knn = Classifier::KNN.new(k: 5, weighted: true)

# Add training examples
knn.add(
  positive: [
    "Amazing quality, exceeded expectations!",
    "Best purchase I've made this year",
    "Fast shipping and great customer service"
  ],
  negative: [
    "Complete waste of money",
    "Broke after one week",
    "Terrible quality, avoid"
  ],
  neutral: [
    "It's okay, nothing special",
    "Does what it says, no more no less",
    "Average product for the price"
  ]
)

# Classify with explanation
result = knn.classify_with_neighbors "Excellent product, highly recommend!"

puts "Category: #{result[:category]}"
puts "Confidence: #{(result[:confidence] * 100).round}%"
puts "Top neighbors:"
result[:neighbors].first(3).each do |n|
  puts "  - #{n[:category]}: #{n[:item][0..50]}... (#{(n[:similarity] * 100).round}%)"
end
```

## Streaming & Batch Training

For larger datasets, use batch training with progress callbacks:

```ruby
knn = Classifier::KNN.new(k: 5)

# Batch training with progress tracking
knn.train_batch(
  spam: spam_documents,
  ham: ham_documents,
  batch_size: 500
) do |progress|
  puts "#{progress.percent}% complete (#{progress.rate.round} docs/sec)"
end
```

For files too large to load into memory, stream line-by-line:

```ruby
File.open('spam_corpus.txt', 'r') do |file|
  knn.train_from_stream(:spam, file, batch_size: 500) do |progress|
    puts "Processed #{progress.completed} lines"
  end
end
```

See the [Streaming Training Tutorial](/docs/tutorials/streaming-training) for checkpoints and resumable training.

## Persistence

Save and load your classifier:

```ruby
# Save to file
knn.save_to_file("reviews_classifier.json")

# Load later
loaded = Classifier::KNN.load_from_file("reviews_classifier.json")

# Or use storage backends
knn.storage = Classifier::Storage::File.new(path: "classifier.json")
knn.save
```

## API Consistency

kNN shares a consistent API with Bayes and LogisticRegression, making it easy to swap classifiers:

| Method | Bayes | LogisticRegression | kNN |
|--------|-------|-------------------|-----|
| `train(cat: text)` | ✓ | ✓ | ✓ |
| `train_category(text)` | ✓ | ✓ | ✓ |
| `classify(text)` → `String` | ✓ | ✓ | ✓ |
| `categories` → `Array[String]` | ✓ | ✓ | ✓ |

This means you can write classifier-agnostic code:

```ruby
def train_classifier(classifier, data)
  data.each { |category, texts| classifier.train(category => texts) }
end

def evaluate(classifier, test_cases)
  test_cases.count { |text, expected| classifier.classify(text) == expected }
end

# Works with any classifier
[Classifier::Bayes.new(:a, :b), Classifier::KNN.new, Classifier::LogisticRegression.new(:a, :b)].each do |c|
  train_classifier(c, training_data)
  puts evaluate(c, test_data)
end
```

## Next Steps

- [Streaming Training](/docs/tutorials/streaming-training) - Train on large datasets with progress tracking
- [Persistence](/docs/guides/persistence/basics) - Save and load classifiers
- [LSI Basics](/docs/guides/lsi/basics) - Understand the similarity engine behind kNN
