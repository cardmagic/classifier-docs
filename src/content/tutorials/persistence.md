---
title: "Save and Load Classifiers"
description: "Persist trained classifiers to disk and reload them for production use."
difficulty: beginner
order: 3
---

# Save and Load Classifiers

Training a classifier takes time. You don't want to retrain every time your application starts. In this tutorial, you'll learn how to save trained classifiers and load them back.

## What You'll Learn

- Saving classifiers to files
- Loading pre-trained classifiers
- Using different storage backends
- Building a reusable model manager

## The Problem

Without persistence, you'd need to retrain on every app restart:

```ruby
# This runs every time your app starts - slow!
classifier = Classifier::Bayes.new 'Positive', 'Negative'
1000.times do |i|
  classifier.train(positive: training_data[i])
end
```

With persistence, you train once and load instantly:

```ruby
# Fast - loads pre-trained model
classifier = Classifier::Bayes.load(storage: storage)
```

## Basic Save and Load

Create `train_and_save.rb`:

```ruby
require 'classifier'

# Create and train the classifier
classifier = Classifier::Bayes.new 'Tech', 'Sports', 'Politics'

classifier.train(tech: "New JavaScript framework released today")
classifier.train(tech: "Apple announces new MacBook Pro")
classifier.train(tech: "Python 4.0 features announced")

classifier.train(sports: "Lakers win championship game")
classifier.train(sports: "World Cup finals draw huge crowd")
classifier.train(sports: "Tennis star wins grand slam")

classifier.train(politics: "Senate passes new legislation")
classifier.train(politics: "Election results announced")
classifier.train(politics: "New policy affects healthcare")

# Configure file storage
classifier.storage = Classifier::Storage::File.new(path: "news_classifier.json")

# Save to disk
classifier.save

puts "Classifier saved to news_classifier.json"
```

Now create `load_and_use.rb`:

```ruby
require 'classifier'

# Configure the same storage
storage = Classifier::Storage::File.new(path: "news_classifier.json")

# Load the pre-trained classifier
classifier = Classifier::Bayes.load(storage: storage)

# Use it immediately - no training needed!
test_articles = [
  "Google releases new AI model",
  "Football team signs star player",
  "Congress debates new bill",
]

test_articles.each do |article|
  category = classifier.classify(article)
  puts "#{category}: #{article}"
end
```

Run the scripts:

```bash
ruby train_and_save.rb
# => Classifier saved to news_classifier.json

ruby load_and_use.rb
# => Tech: Google releases new AI model
# => Sports: Football team signs star player
# => Politics: Congress debates new bill
```

## Building a Model Manager

For production apps, wrap persistence in a manager class. Create `model_manager.rb`:

```ruby
require 'classifier'

class ModelManager
  def initialize(models_dir: "models")
    @models_dir = models_dir
    Dir.mkdir(models_dir) unless Dir.exist?(models_dir)
  end

  def save(classifier, name)
    path = File.join(@models_dir, "#{name}.json")
    classifier.storage = Classifier::Storage::File.new(path: path)
    classifier.save
    puts "Saved #{name} to #{path}"
  end

  def load(name, type: :bayes)
    path = File.join(@models_dir, "#{name}.json")

    unless File.exist?(path)
      raise "Model '#{name}' not found at #{path}"
    end

    storage = Classifier::Storage::File.new(path: path)

    case type
    when :bayes
      Classifier::Bayes.load(storage: storage)
    when :lsi
      Classifier::LSI.load(storage: storage)
    end
  end

  def exists?(name)
    File.exist?(File.join(@models_dir, "#{name}.json"))
  end

  def list
    Dir.glob(File.join(@models_dir, "*.json")).map do |path|
      File.basename(path, ".json")
    end
  end
end
```

Use it in your application:

```ruby
require_relative 'model_manager'

manager = ModelManager.new(models_dir: "trained_models")

# First run: train and save
unless manager.exists?("sentiment")
  classifier = Classifier::Bayes.new 'Positive', 'Negative'

  classifier.train(positive: "I love this product!")
  classifier.train(positive: "Excellent service")
  classifier.train(positive: "Highly recommended")

  classifier.train(negative: "Terrible experience")
  classifier.train(negative: "Waste of money")
  classifier.train(negative: "Very disappointed")

  manager.save(classifier, "sentiment")
end

# All subsequent runs: just load
sentiment = manager.load("sentiment")

puts sentiment.classify("This is amazing!")
# => Positive

puts sentiment.classify("Total garbage")
# => Negative
```

## Checking for Unsaved Changes

The classifier tracks whether you have unsaved changes:

```ruby
classifier = Classifier::Bayes.new :a, :b
classifier.storage = Classifier::Storage::File.new(path: "model.json")

classifier.dirty?
# => false

classifier.train(a: "new training data")
classifier.dirty?
# => true

classifier.save
classifier.dirty?
# => false
```

Use this to prompt users or auto-save:

```ruby
at_exit do
  if classifier.dirty?
    print "You have unsaved changes. Save before exit? (y/n) "
    classifier.save if gets.chomp.downcase == 'y'
  end
end
```

## Using Memory Storage for Tests

In tests, use memory storage to avoid file system dependencies:

```ruby
require 'minitest/autorun'
require 'classifier'

class ClassifierTest < Minitest::Test
  def setup
    @storage = Classifier::Storage::Memory.new
    @classifier = Classifier::Bayes.new 'Spam', 'Ham'
    @classifier.storage = @storage
  end

  def test_persistence_roundtrip
    @classifier.train(spam: "Buy now!")
    @classifier.train(ham: "Meeting at 3pm")
    @classifier.save

    # Load into a new instance
    loaded = Classifier::Bayes.load(storage: @storage)

    assert_equal "Spam", loaded.classify("Buy cheap stuff")
    assert_equal "Ham", loaded.classify("See you at the meeting")
  end

  def test_dirty_tracking
    refute @classifier.dirty?

    @classifier.train(spam: "test")
    assert @classifier.dirty?

    @classifier.save
    refute @classifier.dirty?
  end
end
```

## Complete Example: Persistent Sentiment API

Here's a complete example combining everything. Create `sentiment_api.rb`:

```ruby
require 'classifier'
require 'json'

class SentimentAPI
  MODEL_PATH = "sentiment_model.json"

  def initialize
    @storage = Classifier::Storage::File.new(path: MODEL_PATH)

    if File.exist?(MODEL_PATH)
      @classifier = Classifier::Bayes.load(storage: @storage)
      puts "Loaded existing model"
    else
      @classifier = Classifier::Bayes.new 'Positive', 'Negative', 'Neutral'
      @classifier.storage = @storage
      seed_training_data
      @classifier.save
      puts "Created and saved new model"
    end
  end

  def analyze(text)
    scores = @classifier.classifications(text)
    category = @classifier.classify(text)

    {
      text: text,
      sentiment: category.downcase,
      confidence: calculate_confidence(scores, category)
    }
  end

  def train(text, sentiment)
    @classifier.train(sentiment.downcase.to_sym => text)
    puts "Trained: #{sentiment}"
  end

  def save
    @classifier.save
    puts "Model saved"
  end

  def stats
    {
      categories: ['Positive', 'Negative', 'Neutral'],
      has_unsaved_changes: @classifier.dirty?
    }
  end

  private

  def seed_training_data
    # Positive
    @classifier.train(positive: "I love this!")
    @classifier.train(positive: "Excellent work")
    @classifier.train(positive: "This is fantastic")
    @classifier.train(positive: "Great job, well done")
    @classifier.train(positive: "Amazing results")

    # Negative
    @classifier.train(negative: "This is terrible")
    @classifier.train(negative: "I hate it")
    @classifier.train(negative: "Worst experience ever")
    @classifier.train(negative: "Completely disappointed")
    @classifier.train(negative: "Total waste of time")

    # Neutral
    @classifier.train(neutral: "It's okay I guess")
    @classifier.train(neutral: "Nothing special")
    @classifier.train(neutral: "Average performance")
    @classifier.train(neutral: "Could be better or worse")
    @classifier.train(neutral: "No strong feelings")
  end

  def calculate_confidence(scores, category)
    max_score = scores[category]
    other_scores = scores.values.reject { |s| s == max_score }
    gap = max_score - other_scores.max

    # Convert log probability gap to percentage
    confidence = (1 - Math.exp(-gap.abs)) * 100
    confidence.round(1)
  end
end

# Interactive demo
if __FILE__ == $0
  api = SentimentAPI.new

  loop do
    print "\nEnter text (or 'quit'): "
    input = gets.chomp

    break if input.downcase == 'quit'

    result = api.analyze(input)
    puts "Sentiment: #{result[:sentiment]} (#{result[:confidence]}% confidence)"
  end

  api.save if api.stats[:has_unsaved_changes]
end
```

Run it:

```bash
ruby sentiment_api.rb

# => Loaded existing model (or "Created and saved new model" on first run)
# Enter text (or 'quit'): This product is amazing!
# Sentiment: positive (87.3% confidence)
# Enter text (or 'quit'): I regret buying this
# Sentiment: negative (72.1% confidence)
# Enter text (or 'quit'): quit
```

## Next Steps

- [Persistence Framework Guide](/docs/guides/persistence/basics) - Deep dive into storage backends
- [Build a Spam Filter](/docs/tutorials/spam-filter) - Another practical classifier project
- [LSI Basics](/docs/guides/lsi/basics) - Persist semantic search indexes
