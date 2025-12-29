---
title: "Ensemble Classifier"
description: "Combine Bayes, LSI, and kNN classifiers with weighted voting for higher accuracy than any single model."
difficulty: advanced
classifiers: [bayes, lsi, knn]
order: 11
---

# Ensemble Classifier

Combine multiple classifiers into an ensemble that outperforms any individual model. By leveraging the strengths of Bayes (fast, probabilistic), LSI (semantic understanding), and kNN (interpretable neighbors), you get more robust predictions.

## What You'll Learn

- Building an ensemble from multiple classifier types
- Weighted voting strategies
- Confidence-based model selection
- When ensembles help (and when they don't)

## Why Ensembles Work

Different classifiers have different strengths:

| Classifier | Strength | Weakness |
|------------|----------|----------|
| **Bayes** | Fast, handles large vocab | Assumes word independence |
| **LSI** | Semantic similarity | Slower, needs tuning |
| **kNN** | Interpretable, no training | Slower at scale |

When they disagree, the ensemble can break ties intelligently. When they agree, confidence is high.

## Project Setup

```bash
mkdir ensemble_classifier && cd ensemble_classifier
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## The Ensemble Classifier

Create `ensemble_classifier.rb`:

```ruby
require 'classifier'
require 'json'

class EnsembleClassifier
  STRATEGIES = [:majority_vote, :weighted_vote, :confidence_weighted, :best_confidence]

  def initialize(strategy: :confidence_weighted)
    @bayes = nil
    @lsi = nil
    @knn = nil
    @strategy = strategy
    @categories = []
    @weights = { bayes: 1.0, lsi: 1.0, knn: 1.0 }
  end

  attr_accessor :weights

  # Train all classifiers with the same data
  def train(data_by_category)
    @categories = data_by_category.keys.map(&:to_s)

    # Initialize classifiers
    @bayes = Classifier::Bayes.new(*@categories)
    @lsi = Classifier::LSI.new(auto_rebuild: false)
    @knn = Classifier::KNN.new(k: 5, weighted: true)

    # Train each classifier
    data_by_category.each do |category, items|
      items = Array(items)

      # Bayes
      @bayes.train(category.to_sym => items)

      # LSI and kNN use same format
      @lsi.add(category.to_s => items)
      @knn.add(category.to_sym => items)
    end

    @lsi.build_index
    self
  end

  # Classify using the ensemble
  def classify(text)
    predictions = get_all_predictions(text)
    result = combine_predictions(predictions)

    {
      category: result[:category],
      confidence: result[:confidence],
      strategy: @strategy,
      individual_predictions: predictions,
      agreement: calculate_agreement(predictions)
    }
  end

  # Get detailed breakdown
  def classify_with_details(text)
    result = classify(text)

    result.merge(
      explanation: explain_decision(result),
      recommendation: recommend_action(result)
    )
  end

  # Evaluate ensemble vs individual classifiers
  def evaluate(test_data)
    results = { ensemble: 0, bayes: 0, lsi: 0, knn: 0, total: 0 }

    test_data.each do |item|
      text = item[:text]
      expected = item[:category].to_s

      ensemble_result = classify(text)
      predictions = ensemble_result[:individual_predictions]

      results[:total] += 1
      results[:ensemble] += 1 if ensemble_result[:category] == expected
      results[:bayes] += 1 if predictions[:bayes][:category] == expected
      results[:lsi] += 1 if predictions[:lsi][:category] == expected
      results[:knn] += 1 if predictions[:knn][:category] == expected
    end

    # Calculate accuracies
    total = results[:total].to_f
    {
      ensemble: (results[:ensemble] / total * 100).round(1),
      bayes: (results[:bayes] / total * 100).round(1),
      lsi: (results[:lsi] / total * 100).round(1),
      knn: (results[:knn] / total * 100).round(1),
      total_samples: results[:total]
    }
  end

  def save(path)
    Dir.mkdir(path) unless Dir.exist?(path)

    @bayes.storage = Classifier::Storage::File.new(path: "#{path}/bayes.json")
    @bayes.save

    @lsi.storage = Classifier::Storage::File.new(path: "#{path}/lsi.json")
    @lsi.save

    @knn.storage = Classifier::Storage::File.new(path: "#{path}/knn.json")
    @knn.save

    File.write("#{path}/meta.json", {
      strategy: @strategy,
      weights: @weights,
      categories: @categories
    }.to_json)
  end

  def self.load(path)
    meta = JSON.parse(File.read("#{path}/meta.json"), symbolize_names: true)

    ensemble = new(strategy: meta[:strategy].to_sym)
    ensemble.weights = meta[:weights]
    ensemble.instance_variable_set(:@categories, meta[:categories])

    bayes_storage = Classifier::Storage::File.new(path: "#{path}/bayes.json")
    lsi_storage = Classifier::Storage::File.new(path: "#{path}/lsi.json")
    knn_storage = Classifier::Storage::File.new(path: "#{path}/knn.json")

    ensemble.instance_variable_set(:@bayes, Classifier::Bayes.load(storage: bayes_storage))
    ensemble.instance_variable_set(:@lsi, Classifier::LSI.load(storage: lsi_storage))
    ensemble.instance_variable_set(:@knn, Classifier::KNN.load(storage: knn_storage))

    ensemble
  end

  private

  def get_all_predictions(text)
    {
      bayes: get_bayes_prediction(text),
      lsi: get_lsi_prediction(text),
      knn: get_knn_prediction(text)
    }
  end

  def get_bayes_prediction(text)
    category = @bayes.classify(text)
    scores = @bayes.classifications(text)

    # Convert log probabilities to confidence
    exp_scores = scores.transform_values { |s| Math.exp(s) }
    total = exp_scores.values.sum
    confidence = (exp_scores[category] / total * 100).round(1)

    { category: category, confidence: confidence, scores: scores }
  end

  def get_lsi_prediction(text)
    result = @lsi.classify_with_confidence(text)
    category = result[0]&.to_s
    confidence = ((result[1] || 0) * 100).round(1)

    { category: category, confidence: confidence }
  end

  def get_knn_prediction(text)
    result = @knn.classify_with_neighbors(text)
    category = result[:category]&.to_s
    confidence = (result[:confidence] * 100).round(1)

    { category: category, confidence: confidence, neighbors: result[:neighbors] }
  end

  def combine_predictions(predictions)
    case @strategy
    when :majority_vote
      majority_vote(predictions)
    when :weighted_vote
      weighted_vote(predictions)
    when :confidence_weighted
      confidence_weighted(predictions)
    when :best_confidence
      best_confidence(predictions)
    else
      raise "Unknown strategy: #{@strategy}"
    end
  end

  def majority_vote(predictions)
    votes = predictions.values.map { |p| p[:category] }
    winner = votes.group_by(&:itself).max_by { |_, v| v.size }&.first

    vote_count = votes.count(winner)
    confidence = (vote_count.to_f / votes.size * 100).round(1)

    { category: winner, confidence: confidence }
  end

  def weighted_vote(predictions)
    scores = Hash.new(0.0)

    predictions.each do |classifier, pred|
      next unless pred[:category]
      scores[pred[:category]] += @weights[classifier]
    end

    winner = scores.max_by { |_, v| v }&.first
    total_weight = @weights.values.sum
    confidence = (scores[winner] / total_weight * 100).round(1)

    { category: winner, confidence: confidence }
  end

  def confidence_weighted(predictions)
    scores = Hash.new(0.0)

    predictions.each do |classifier, pred|
      next unless pred[:category]
      weight = @weights[classifier] * (pred[:confidence] / 100.0)
      scores[pred[:category]] += weight
    end

    winner = scores.max_by { |_, v| v }&.first
    total = scores.values.sum
    confidence = total.positive? ? (scores[winner] / total * 100).round(1) : 0

    { category: winner, confidence: confidence }
  end

  def best_confidence(predictions)
    best = predictions.max_by { |_, pred| pred[:confidence] }
    { category: best[1][:category], confidence: best[1][:confidence], chosen_by: best[0] }
  end

  def calculate_agreement(predictions)
    categories = predictions.values.map { |p| p[:category] }.compact
    return 0 if categories.empty?

    most_common = categories.group_by(&:itself).max_by { |_, v| v.size }
    (most_common[1].size.to_f / categories.size * 100).round(1)
  end

  def explain_decision(result)
    preds = result[:individual_predictions]
    agreement = result[:agreement]

    if agreement == 100
      "All classifiers agree on '#{result[:category]}'"
    elsif agreement >= 66
      "Majority (#{agreement.round}%) agree on '#{result[:category]}'"
    else
      disagreements = preds.map { |c, p| "#{c}=#{p[:category]}" }.join(", ")
      "Classifiers disagree (#{disagreements}), resolved by #{@strategy}"
    end
  end

  def recommend_action(result)
    if result[:confidence] >= 80 && result[:agreement] >= 66
      :auto_classify
    elsif result[:confidence] >= 50
      :suggest_with_review
    else
      :manual_review
    end
  end
end
```

## Training the Ensemble

Create `train.rb`:

```ruby
require_relative 'ensemble_classifier'

ensemble = EnsembleClassifier.new(strategy: :confidence_weighted)

# Training data
training_data = {
  tech: [
    "New JavaScript framework released for frontend development",
    "Python machine learning library updated with GPU support",
    "Kubernetes deployment best practices for microservices",
    "React hooks tutorial for state management",
    "Database optimization techniques for PostgreSQL",
    "API design patterns for RESTful services",
    "Docker container security best practices",
    "TypeScript generics explained with examples",
  ],
  sports: [
    "Team wins championship after overtime victory",
    "Star player signs record-breaking contract",
    "Coach announces new training strategy for season",
    "League announces rule changes for next year",
    "Athlete breaks world record at competition",
    "Team trades draft pick for veteran player",
    "Stadium renovations completed before opener",
    "Player returns from injury ahead of schedule",
  ],
  finance: [
    "Stock market reaches all-time high amid earnings",
    "Federal Reserve announces interest rate decision",
    "Cryptocurrency volatility concerns investors",
    "Company reports quarterly earnings beat expectations",
    "Merger announcement drives stock price surge",
    "Economic indicators suggest recession concerns",
    "Investment strategies for volatile markets",
    "Banking sector faces regulatory changes",
  ],
  entertainment: [
    "New streaming series breaks viewership records",
    "Award show announces nominees for best picture",
    "Celebrity announces upcoming concert tour dates",
    "Movie sequel announced for summer release",
    "Album debuts at top of music charts",
    "TV show renewed for additional seasons",
    "Director reveals plans for franchise reboot",
    "Festival lineup announced with headliners",
  ]
}

ensemble.train(training_data)
ensemble.save('ensemble_model')

puts "Trained ensemble with #{training_data.keys.length} categories"
puts "Total examples: #{training_data.values.flatten.length}"
```

## Classifying with the Ensemble

Create `classify.rb`:

```ruby
require_relative 'ensemble_classifier'

ensemble = EnsembleClassifier.load('ensemble_model')

test_texts = [
  "The new React 19 release includes server components and improved hooks",
  "Lakers defeat Celtics in thrilling game seven overtime",
  "Fed raises rates as inflation concerns persist in economy",
  "Oscar nominations announced for best picture category",
  "Startup raises funding to build quantum computing platform",  # Ambiguous
]

puts "=" * 70
puts "ENSEMBLE CLASSIFIER"
puts "=" * 70

test_texts.each do |text|
  puts "\nText: #{text[0..60]}..."
  puts "-" * 50

  result = ensemble.classify_with_details(text)

  puts "Result: #{result[:category]} (#{result[:confidence]}% confidence)"
  puts "Agreement: #{result[:agreement]}%"
  puts "Explanation: #{result[:explanation]}"
  puts "Recommendation: #{result[:recommendation]}"

  puts "\nIndividual predictions:"
  result[:individual_predictions].each do |classifier, pred|
    puts "  #{classifier.to_s.ljust(6)}: #{pred[:category]} (#{pred[:confidence]}%)"
  end
end
```

## Comparing Strategies

Create `compare_strategies.rb`:

```ruby
require_relative 'ensemble_classifier'

# Test data (separate from training!)
test_data = [
  { text: "Python library for data science released", category: "tech" },
  { text: "Team wins playoff series in seven games", category: "sports" },
  { text: "Stock prices fall amid market uncertainty", category: "finance" },
  { text: "New movie breaks box office records", category: "entertainment" },
  { text: "JavaScript framework simplifies web development", category: "tech" },
  { text: "Player traded to rival team for picks", category: "sports" },
  { text: "Central bank holds interest rates steady", category: "finance" },
  { text: "Concert tour announced for summer dates", category: "entertainment" },
  # Add more test cases...
]

strategies = [:majority_vote, :weighted_vote, :confidence_weighted, :best_confidence]

puts "=" * 60
puts "STRATEGY COMPARISON"
puts "=" * 60

strategies.each do |strategy|
  ensemble = EnsembleClassifier.load('ensemble_model')
  ensemble.instance_variable_set(:@strategy, strategy)

  accuracy = ensemble.evaluate(test_data)

  puts "\n#{strategy}:"
  puts "  Ensemble: #{accuracy[:ensemble]}%"
  puts "  vs Bayes: #{accuracy[:bayes]}% | LSI: #{accuracy[:lsi]}% | kNN: #{accuracy[:knn]}%"
end
```

## Tuning Weights

```ruby
# Give more weight to classifiers that perform better on your domain
ensemble.weights = {
  bayes: 1.2,  # Boost Bayes (fast, good for distinct categories)
  lsi: 0.8,   # Lower LSI (if semantic similarity less important)
  knn: 1.0    # Keep kNN normal
}

# Or tune based on evaluation
def auto_tune_weights(ensemble, validation_data)
  best_weights = ensemble.weights.dup
  best_accuracy = ensemble.evaluate(validation_data)[:ensemble]

  # Simple grid search
  [0.5, 0.8, 1.0, 1.2, 1.5].each do |bayes_w|
    [0.5, 0.8, 1.0, 1.2, 1.5].each do |lsi_w|
      [0.5, 0.8, 1.0, 1.2, 1.5].each do |knn_w|
        ensemble.weights = { bayes: bayes_w, lsi: lsi_w, knn: knn_w }
        accuracy = ensemble.evaluate(validation_data)[:ensemble]

        if accuracy > best_accuracy
          best_accuracy = accuracy
          best_weights = ensemble.weights.dup
        end
      end
    end
  end

  ensemble.weights = best_weights
  { weights: best_weights, accuracy: best_accuracy }
end
```

## When to Use Ensembles

**Good for:**
- High-stakes classification where accuracy matters
- Ambiguous text that might confuse single classifiers
- When you need confidence scoring for manual review routing

**Not ideal for:**
- Simple, clear-cut categories (single classifier is enough)
- Latency-sensitive applications (3x the computation)
- Very large scale (memory for 3 models)

## Best Practices

1. **Use validation data for tuning**: Don't tune on training data
2. **Monitor individual classifier performance**: If one is always wrong, lower its weight
3. **Consider the agreement score**: High disagreement = uncertain prediction
4. **Route low-confidence to humans**: Use the recommendation field

## Next Steps

- [Bayes Basics](/docs/guides/bayes/basics) - Understand probabilistic classification
- [LSI Basics](/docs/guides/lsi/basics) - Semantic similarity under the hood
- [kNN Basics](/docs/guides/knn/basics) - Instance-based classification
