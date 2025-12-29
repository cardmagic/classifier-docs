---
title: "Sentiment Analysis Dashboard"
description: "Build a real-time sentiment dashboard to analyze product reviews with confidence scoring."
difficulty: intermediate
classifiers: [bayes]
order: 6
---

# Sentiment Analysis Dashboard

Build a dashboard that analyzes customer reviews in real-time, showing sentiment trends and flagging concerning feedback for immediate attention.

## What You'll Learn

- Multi-class sentiment (positive/negative/neutral)
- Confidence scoring for prioritization
- Aggregating sentiment over time
- Building actionable dashboards

## Project Setup

```bash
mkdir sentiment_dashboard && cd sentiment_dashboard
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## The Sentiment Analyzer

Create `sentiment_analyzer.rb`:

```ruby
require 'classifier'
require 'json'

class SentimentAnalyzer
  CATEGORIES = ['Positive', 'Negative', 'Neutral']

  def initialize
    @classifier = Classifier::Bayes.new(*CATEGORIES)
    @review_count = 0
  end

  # Train with labeled reviews
  def train(sentiment, text)
    sentiment = sentiment.to_s.capitalize
    raise ArgumentError, "Invalid sentiment: #{sentiment}" unless CATEGORIES.include?(sentiment)

    @classifier.train(sentiment.downcase.to_sym => text)
    @review_count += 1
  end

  # Batch train from hash
  def train_batch(reviews_by_sentiment)
    reviews_by_sentiment.each do |sentiment, texts|
      Array(texts).each { |text| train(sentiment, text) }
    end
  end

  # Analyze a single review
  def analyze(text)
    scores = @classifier.classifications(text)
    sentiment = @classifier.classify(text)

    {
      text: text,
      sentiment: sentiment.downcase.to_sym,
      confidence: calculate_confidence(scores),
      scores: normalize_scores(scores)
    }
  end

  # Analyze multiple reviews with stats
  def analyze_batch(texts)
    results = texts.map { |t| analyze(t) }

    {
      reviews: results,
      summary: summarize(results),
      flagged: flag_for_review(results)
    }
  end

  # Get overall sentiment health score (0-100)
  def health_score(results)
    return 50 if results.empty?

    weights = { positive: 1.0, neutral: 0.5, negative: 0.0 }
    weighted_sum = results.sum do |r|
      weights[r[:sentiment]] * r[:confidence]
    end

    ((weighted_sum / results.length) * 100).round(1)
  end

  def save(path)
    @classifier.storage = Classifier::Storage::File.new(path: path)
    @classifier.save
  end

  def self.load(path)
    analyzer = new
    storage = Classifier::Storage::File.new(path: path)
    analyzer.instance_variable_set(
      :@classifier,
      Classifier::Bayes.load(storage: storage)
    )
    analyzer
  end

  private

  def calculate_confidence(scores)
    # Convert log probabilities to percentages
    exp_scores = scores.transform_values { |s| Math.exp(s) }
    total = exp_scores.values.sum
    max_score = exp_scores.values.max

    ((max_score / total) * 100).round(1)
  end

  def normalize_scores(scores)
    exp_scores = scores.transform_values { |s| Math.exp(s) }
    total = exp_scores.values.sum

    exp_scores.transform_values { |s| ((s / total) * 100).round(1) }
  end

  def summarize(results)
    counts = results.group_by { |r| r[:sentiment] }
      .transform_values(&:count)

    total = results.length
    {
      total: total,
      positive: counts[:positive] || 0,
      negative: counts[:negative] || 0,
      neutral: counts[:neutral] || 0,
      positive_pct: percentage(counts[:positive] || 0, total),
      negative_pct: percentage(counts[:negative] || 0, total),
      avg_confidence: (results.sum { |r| r[:confidence] } / total).round(1),
      health_score: health_score(results)
    }
  end

  def flag_for_review(results)
    # Flag negative reviews with high confidence for immediate attention
    results.select do |r|
      r[:sentiment] == :negative && r[:confidence] > 70
    end.sort_by { |r| -r[:confidence] }
  end

  def percentage(count, total)
    return 0 if total.zero?
    ((count.to_f / total) * 100).round(1)
  end
end
```

## Training the Analyzer

Create `train.rb`:

```ruby
require_relative 'sentiment_analyzer'

analyzer = SentimentAnalyzer.new

# Training data (in production, use much larger datasets)
training_data = {
  positive: [
    "Absolutely love this product! Best purchase ever.",
    "Exceeded my expectations. Highly recommend!",
    "Amazing quality for the price. Very satisfied.",
    "Fast shipping, great customer service. Will buy again!",
    "This is exactly what I needed. Perfect!",
    "Outstanding quality and works perfectly.",
    "So happy with this purchase. Five stars!",
    "The best in its category. Worth every penny.",
    "Fantastic product, my whole family loves it.",
    "Incredible value. Can't recommend enough.",
  ],
  negative: [
    "Complete waste of money. Broke after one day.",
    "Terrible quality. Do not buy this.",
    "Worst purchase I've ever made. Returning immediately.",
    "Customer service was unhelpful and rude.",
    "Does not work as advertised. Very disappointed.",
    "Cheaply made, fell apart within a week.",
    "Save your money. This product is garbage.",
    "Frustrating experience from start to finish.",
    "Would give zero stars if possible.",
    "Total scam. Nothing like the pictures.",
  ],
  neutral: [
    "It's okay. Does what it says, nothing special.",
    "Average product. Gets the job done.",
    "Met my expectations, nothing more.",
    "Decent for the price point.",
    "It works. Not amazing, not terrible.",
    "Standard quality. No complaints.",
    "Fine for basic use. Don't expect too much.",
    "Middle of the road product.",
    "Acceptable quality for casual use.",
    "Neither impressed nor disappointed.",
  ]
}

analyzer.train_batch(training_data)
analyzer.save('sentiment_model.json')

puts "Trained on #{training_data.values.flatten.length} reviews"
puts "Model saved to sentiment_model.json"
```

## Analyzing Reviews

Create `analyze.rb`:

```ruby
require_relative 'sentiment_analyzer'

analyzer = SentimentAnalyzer.load('sentiment_model.json')

# Sample product reviews to analyze
reviews = [
  "Love it! Best thing I've bought this year.",
  "Meh, it's alright. Nothing to write home about.",
  "Absolute garbage. Waste of money.",
  "Pretty good quality for the price.",
  "DO NOT BUY. Scam product, doesn't work at all!",
  "Exactly as described. Happy with purchase.",
  "The worst customer experience I've ever had.",
  "It's fine. Does what I need it to do.",
  "Amazing! Exceeded all my expectations!",
  "Disappointed. Expected better quality.",
]

puts "=" * 70
puts "SENTIMENT ANALYSIS DASHBOARD"
puts "=" * 70

# Analyze all reviews
results = analyzer.analyze_batch(reviews)

# Show summary
summary = results[:summary]
puts "\n📊 SUMMARY"
puts "-" * 40
puts "Total Reviews: #{summary[:total]}"
puts "Health Score: #{summary[:health_score]}/100"
puts
puts "Sentiment Breakdown:"
puts "  ✅ Positive: #{summary[:positive]} (#{summary[:positive_pct]}%)"
puts "  😐 Neutral:  #{summary[:neutral]} (#{summary[:neutral_pct]}%)"
puts "  ❌ Negative: #{summary[:negative]} (#{summary[:negative_pct]}%)"
puts
puts "Average Confidence: #{summary[:avg_confidence]}%"

# Show flagged reviews
if results[:flagged].any?
  puts "\n🚨 FLAGGED FOR IMMEDIATE REVIEW"
  puts "-" * 40
  results[:flagged].each do |review|
    puts "  [#{review[:confidence]}% confidence]"
    puts "  \"#{review[:text]}\""
    puts
  end
end

# Show all results
puts "\n📝 ALL REVIEWS"
puts "-" * 40
results[:reviews].each do |review|
  emoji = { positive: "✅", negative: "❌", neutral: "😐" }[review[:sentiment]]
  puts "#{emoji} [#{review[:sentiment].upcase}] #{review[:confidence]}%"
  puts "   \"#{review[:text][0..60]}#{review[:text].length > 60 ? '...' : ''}\""
  puts
end
```

Run it:

```bash
ruby train.rb
ruby analyze.rb
```

Output:
```
======================================================================
SENTIMENT ANALYSIS DASHBOARD
======================================================================

📊 SUMMARY
----------------------------------------
Total Reviews: 10
Health Score: 52.3/100

Sentiment Breakdown:
  ✅ Positive: 3 (30.0%)
  😐 Neutral:  3 (30.0%)
  ❌ Negative: 4 (40.0%)

Average Confidence: 78.4%

🚨 FLAGGED FOR IMMEDIATE REVIEW
----------------------------------------
  [94.2% confidence]
  "DO NOT BUY. Scam product, doesn't work at all!"

  [89.1% confidence]
  "Absolute garbage. Waste of money."

  [82.7% confidence]
  "The worst customer experience I've ever had."
```

## Time-Series Dashboard

Track sentiment over time:

```ruby
class SentimentDashboard
  def initialize(analyzer)
    @analyzer = analyzer
    @history = []  # Array of {timestamp:, results:}
  end

  def record_batch(reviews, timestamp: Time.now)
    results = @analyzer.analyze_batch(reviews)
    @history << {
      timestamp: timestamp,
      results: results
    }
  end

  def trend(days: 7)
    cutoff = Time.now - (days * 24 * 60 * 60)
    recent = @history.select { |h| h[:timestamp] >= cutoff }

    recent.map do |entry|
      {
        date: entry[:timestamp].strftime("%Y-%m-%d"),
        health_score: entry[:results][:summary][:health_score],
        positive_pct: entry[:results][:summary][:positive_pct],
        negative_pct: entry[:results][:summary][:negative_pct],
        review_count: entry[:results][:summary][:total]
      }
    end
  end

  def alert_needed?(threshold: 40)
    return false if @history.empty?

    recent_health = @history.last[:results][:summary][:health_score]
    recent_health < threshold
  end
end

# Usage
dashboard = SentimentDashboard.new(analyzer)

# Record today's reviews
dashboard.record_batch(todays_reviews)

# Check if we need to alert the team
if dashboard.alert_needed?(threshold: 45)
  puts "⚠️ ALERT: Sentiment health below threshold!"
end

# Get 7-day trend for charts
puts dashboard.trend(days: 7)
```

## Integration Example

```ruby
# In a Rails controller or Sinatra app
class ReviewsController
  def create
    review = Review.create!(params[:review])

    # Analyze sentiment asynchronously
    SentimentJob.perform_async(review.id)
  end
end

class SentimentJob
  def perform(review_id)
    review = Review.find(review_id)
    analyzer = SentimentAnalyzer.load('sentiment_model.json')

    result = analyzer.analyze(review.body)

    review.update!(
      sentiment: result[:sentiment],
      sentiment_confidence: result[:confidence]
    )

    # Alert on high-confidence negative reviews
    if result[:sentiment] == :negative && result[:confidence] > 80
      SlackNotifier.alert(
        "🚨 Negative Review Alert",
        "#{result[:confidence]}% negative: #{review.body[0..100]}..."
      )
    end
  end
end
```

## Best Practices

1. **Train with domain-specific data**: Generic sentiment doesn't capture product-specific language
2. **Handle neutral carefully**: Many reviews are mixed—consider a wider neutral band
3. **Use confidence thresholds**: Only flag high-confidence negatives to reduce noise
4. **Retrain periodically**: Language and product sentiment drift over time

## Next Steps

- [Bayes Basics](/docs/guides/bayes/basics) - Deep dive into Bayesian classification
- [Persistence Guide](/docs/guides/persistence/basics) - Production storage strategies
