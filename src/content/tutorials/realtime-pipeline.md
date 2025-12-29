---
title: "Real-time Classification Pipeline"
description: "Build a scalable pipeline for classifying streaming data with background jobs, Redis caching, and concurrent processing."
difficulty: advanced
classifiers: [bayes, lsi]
order: 12
---

# Real-time Classification Pipeline

Build a production-ready pipeline that classifies incoming data in real-time. This architecture handles high throughput, maintains classifier state with Redis, and processes items concurrently.

## What You'll Learn

- Background job processing with Sidekiq
- Redis-backed classifier caching
- Concurrent classification with thread safety
- Webhook integration for real-time updates
- Scaling strategies for high throughput

## Architecture Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Incoming   │────▶│   Redis     │────▶│  Sidekiq    │
│  Webhook    │     │   Queue     │     │  Workers    │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                    ┌─────────────┐            │
                    │  Classifier │◀───────────┘
                    │   (cached)  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Results DB │
                    └─────────────┘
```

## Project Setup

```bash
mkdir classification_pipeline && cd classification_pipeline
```

```ruby
# Gemfile
source 'https://rubygems.org'

gem 'classifier'
gem 'sidekiq', '~> 7.0'
gem 'redis', '~> 5.0'
gem 'sinatra'
gem 'connection_pool'
```

## Redis Storage Backend

First, implement a Redis storage backend following the gem's storage protocol. Create `lib/storage/redis.rb`:

```ruby
require 'classifier'

module Classifier
  module Storage
    class Redis < Base
      def initialize(redis_pool:, key:, ttl: 3600)
        @redis_pool = redis_pool
        @key = key
        @ttl = ttl
      end

      def write(data)
        @redis_pool.with { |r| r.setex(@key, @ttl, data) }
      end

      def read
        @redis_pool.with { |r| r.get(@key) }
      end

      def delete
        @redis_pool.with { |r| r.del(@key) }
      end

      def exists?
        @redis_pool.with { |r| r.exists?(@key) }
      end
    end
  end
end
```

## The Cached Classifier

Now build a thread-safe wrapper that uses the storage backend. Create `lib/cached_classifier.rb`:

```ruby
require 'classifier'
require 'redis'
require 'connection_pool'
require_relative 'storage/redis'

class CachedClassifier
  LOCK_TTL = 10  # 10 seconds for rebuild lock

  def initialize(name:, categories:, redis_pool:, ttl: 3600)
    @name = name
    @categories = categories
    @redis_pool = redis_pool
    @ttl = ttl
    @local_classifier = nil
    @local_version = nil
  end

  # Thread-safe classification
  def classify(text)
    classifier = get_or_build_classifier
    classifier.classify(text)
  end

  # Thread-safe scoring
  def classifications(text)
    classifier = get_or_build_classifier
    classifier.classifications(text)
  end

  # Train and persist to Redis
  def train(category, text)
    with_lock do
      classifier = get_or_build_classifier
      classifier.train(category.to_sym => text)
      classifier.save
      increment_version
      true
    end
  end

  # Batch train (more efficient)
  def batch_train(training_data)
    with_lock do
      classifier = get_or_build_classifier

      training_data.each do |category, texts|
        classifier.train(category.to_sym => Array(texts))
      end

      classifier.save
      increment_version
      true
    end
  end

  # Force rebuild from training data
  def rebuild!
    storage.delete
    increment_version
    @local_classifier = nil
    @local_version = nil
  end

  private

  def storage
    @storage ||= Classifier::Storage::Redis.new(
      redis_pool: @redis_pool,
      key: "classifier:#{@name}:state",
      ttl: @ttl
    )
  end

  def get_or_build_classifier
    current_version = get_version

    # Return cached if version matches
    if @local_classifier && @local_version == current_version
      return @local_classifier
    end

    # Load from Redis or create new
    @local_classifier = load_or_create_classifier
    @local_version = current_version
    @local_classifier
  end

  def load_or_create_classifier
    if storage.exists?
      Classifier::Bayes.load(storage: storage)
    else
      classifier = Classifier::Bayes.new(*@categories)
      classifier.storage = storage
      classifier
    end
  end

  def get_version
    @redis_pool.with { |r| r.get(version_key).to_i }
  end

  def increment_version
    @redis_pool.with { |r| r.incr(version_key) }
    @local_version = nil  # Force reload on next access
  end

  def version_key
    "classifier:#{@name}:version"
  end

  def with_lock
    lock_key = "classifier:#{@name}:lock"
    @redis_pool.with do |redis|
      return false unless redis.set(lock_key, "1", nx: true, ex: LOCK_TTL)
      begin
        yield
      ensure
        redis.del(lock_key)
      end
    end
  end
end
```

This approach:
- Uses the gem's standard `Storage` protocol
- Gets dirty tracking for free via `classifier.save`
- Is consistent with file-based persistence patterns
- Makes it easy to swap storage backends

## Sidekiq Worker

Create `lib/workers/classification_worker.rb`:

```ruby
require 'sidekiq'
require_relative '../cached_classifier'

class ClassificationWorker
  include Sidekiq::Job

  sidekiq_options queue: :classification, retry: 3

  # Class-level connection pool (shared across workers)
  def self.redis_pool
    @redis_pool ||= ConnectionPool.new(size: 10, timeout: 5) do
      Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end
  end

  # Shared classifiers (thread-safe via CachedClassifier)
  def self.classifiers
    @classifiers ||= {}
  end

  def self.get_classifier(name, categories)
    classifiers[name] ||= CachedClassifier.new(
      name: name,
      categories: categories,
      redis_pool: redis_pool
    )
  end

  def perform(item_id, text, classifier_name, categories, callback_url = nil)
    classifier = self.class.get_classifier(classifier_name, categories.map(&:to_sym))

    # Classify
    start_time = Time.now
    result = classifier.classify(text)
    scores = classifier.classifications(text)
    duration = ((Time.now - start_time) * 1000).round(2)

    # Store result
    store_result(item_id, {
      category: result,
      scores: scores,
      duration_ms: duration,
      classified_at: Time.now.iso8601
    })

    # Optional webhook callback
    send_callback(callback_url, item_id, result, scores) if callback_url

    result
  rescue StandardError => e
    Sidekiq.logger.error("Classification failed for #{item_id}: #{e.message}")
    raise
  end

  private

  def store_result(item_id, result)
    self.class.redis_pool.with do |redis|
      redis.hset("results:#{item_id}", result.transform_keys(&:to_s).transform_values(&:to_json))
      redis.expire("results:#{item_id}", 86400)  # 24 hour TTL
    end
  end

  def send_callback(url, item_id, category, scores)
    require 'net/http'
    require 'uri'

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = {
      item_id: item_id,
      category: category,
      scores: scores
    }.to_json

    http.request(request)
  rescue StandardError => e
    Sidekiq.logger.warn("Callback failed: #{e.message}")
  end
end
```

## Training Worker

Create `lib/workers/training_worker.rb`:

```ruby
require 'sidekiq'
require_relative '../cached_classifier'

class TrainingWorker
  include Sidekiq::Job

  sidekiq_options queue: :training, retry: 3

  def perform(classifier_name, categories, category, text)
    classifier = ClassificationWorker.get_classifier(
      classifier_name,
      categories.map(&:to_sym)
    )

    classifier.train(category.to_sym, text)
  end
end

class BatchTrainingWorker
  include Sidekiq::Job

  sidekiq_options queue: :training, retry: 3

  def perform(classifier_name, categories, training_data)
    classifier = ClassificationWorker.get_classifier(
      classifier_name,
      categories.map(&:to_sym)
    )

    # Convert string keys to symbols
    data = training_data.transform_keys(&:to_sym)
    classifier.batch_train(data)
  end
end
```

## Web API

Create `app.rb`:

```ruby
require 'sinatra'
require 'json'
require_relative 'lib/workers/classification_worker'
require_relative 'lib/workers/training_worker'

set :port, 4567

# Classify a single item
post '/classify' do
  content_type :json

  data = JSON.parse(request.body.read)

  item_id = data['id'] || SecureRandom.uuid
  text = data['text']
  classifier = data['classifier'] || 'default'
  categories = data['categories'] || %w[positive negative neutral]
  callback = data['callback_url']

  # Enqueue classification job
  job_id = ClassificationWorker.perform_async(
    item_id, text, classifier, categories, callback
  )

  {
    status: 'queued',
    item_id: item_id,
    job_id: job_id
  }.to_json
end

# Classify multiple items
post '/classify/batch' do
  content_type :json

  data = JSON.parse(request.body.read)
  items = data['items']
  classifier = data['classifier'] || 'default'
  categories = data['categories'] || %w[positive negative neutral]
  callback = data['callback_url']

  job_ids = items.map do |item|
    item_id = item['id'] || SecureRandom.uuid
    ClassificationWorker.perform_async(
      item_id, item['text'], classifier, categories, callback
    )
    { item_id: item_id }
  end

  { status: 'queued', items: job_ids }.to_json
end

# Get classification result
get '/result/:id' do
  content_type :json

  redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  result = redis.hgetall("results:#{params[:id]}")

  if result.empty?
    status 404
    { error: 'not_found' }.to_json
  else
    result.transform_values { |v| JSON.parse(v) }.to_json
  end
end

# Train the classifier
post '/train' do
  content_type :json

  data = JSON.parse(request.body.read)
  classifier = data['classifier'] || 'default'
  categories = data['categories'] || %w[positive negative neutral]

  if data['batch']
    # Batch training
    BatchTrainingWorker.perform_async(classifier, categories, data['batch'])
    { status: 'training_queued', mode: 'batch' }.to_json
  else
    # Single item training
    TrainingWorker.perform_async(
      classifier, categories, data['category'], data['text']
    )
    { status: 'training_queued', mode: 'single' }.to_json
  end
end

# Health check
get '/health' do
  content_type :json

  redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  redis.ping

  {
    status: 'healthy',
    queues: Sidekiq::Stats.new.queues
  }.to_json
rescue StandardError => e
  status 503
  { status: 'unhealthy', error: e.message }.to_json
end
```

## Sidekiq Configuration

Create `config/sidekiq.yml`:

```yaml
:concurrency: 10
:queues:
  - [classification, 3]
  - [training, 1]
  - default
```

## Running the Pipeline

Start Redis:
```bash
redis-server
```

Start Sidekiq:
```bash
bundle exec sidekiq -r ./app.rb -C config/sidekiq.yml
```

Start the API:
```bash
ruby app.rb
```

## Using the Pipeline

### Initial Training

```bash
# Batch train the classifier
curl -X POST http://localhost:4567/train \
  -H "Content-Type: application/json" \
  -d '{
    "classifier": "sentiment",
    "categories": ["positive", "negative", "neutral"],
    "batch": {
      "positive": [
        "Great product, love it!",
        "Excellent service, highly recommend",
        "Amazing quality, very happy"
      ],
      "negative": [
        "Terrible experience, never again",
        "Poor quality, waste of money",
        "Awful service, very disappointed"
      ],
      "neutral": [
        "Product arrived on time",
        "It works as described",
        "Standard quality, nothing special"
      ]
    }
  }'
```

### Real-time Classification

```bash
# Single item
curl -X POST http://localhost:4567/classify \
  -H "Content-Type: application/json" \
  -d '{
    "id": "review-123",
    "text": "This is the best purchase I have ever made!",
    "classifier": "sentiment",
    "categories": ["positive", "negative", "neutral"]
  }'

# Get result
curl http://localhost:4567/result/review-123
```

### Batch Classification

```bash
curl -X POST http://localhost:4567/classify/batch \
  -H "Content-Type: application/json" \
  -d '{
    "classifier": "sentiment",
    "categories": ["positive", "negative", "neutral"],
    "items": [
      {"id": "r1", "text": "Love this product!"},
      {"id": "r2", "text": "Not worth the price"},
      {"id": "r3", "text": "Delivery was on schedule"}
    ],
    "callback_url": "https://your-app.com/webhooks/classification"
  }'
```

## Adding LSI for Semantic Classification

For semantic similarity, add an LSI-backed classifier:

```ruby
class CachedLSIClassifier
  def initialize(name:, redis_pool:)
    @name = name
    @redis_pool = redis_pool
    @mutex = Mutex.new
    @lsi = nil
    @version = nil
  end

  def add_item(content, category)
    @mutex.synchronize do
      get_lsi.add_item(content, category)
      save_to_redis
    end
  end

  def classify(text)
    @mutex.synchronize do
      lsi = get_lsi
      lsi.build_index if lsi.needs_rebuild?
      lsi.classify(text)
    end
  end

  def find_related(text, count: 5)
    @mutex.synchronize do
      lsi = get_lsi
      lsi.build_index if lsi.needs_rebuild?
      lsi.find_related(text, count)
    end
  end

  private

  def get_lsi
    check_version
    @lsi ||= load_or_create
  end

  def check_version
    current = @redis_pool.with { |r| r.get("lsi:#{@name}:version").to_i }
    if @version != current
      @lsi = nil
      @version = current
    end
  end

  def load_or_create
    @redis_pool.with do |redis|
      data = redis.get("lsi:#{@name}:data")
      data ? Classifier::LSI.from_json(data) : Classifier::LSI.new(auto_rebuild: false)
    end
  end

  def save_to_redis
    @redis_pool.with do |redis|
      redis.set("lsi:#{@name}:data", @lsi.to_json)
      redis.incr("lsi:#{@name}:version")
      @version = redis.get("lsi:#{@name}:version").to_i
    end
  end
end
```

## Performance Tips

1. **Use connection pools**: Avoid creating new Redis connections per request
2. **Batch when possible**: `batch_train` is much faster than individual trains
3. **Tune concurrency**: Match Sidekiq workers to your CPU cores
4. **Monitor queue depth**: Set alerts if queues back up
5. **Use callbacks**: Don't poll for results; use webhooks

## Scaling Considerations

| Throughput | Architecture |
|------------|--------------|
| < 100/min | Single Sidekiq process |
| 100-1000/min | Multiple Sidekiq processes |
| 1000+/min | Kubernetes with auto-scaling |

## Next Steps

- [Bayes Basics](/docs/guides/bayes/basics) - Understanding Naive Bayes
- [LSI Basics](/docs/guides/lsi/basics) - Semantic classification
- [Persistence Guide](/docs/guides/persistence/basics) - Storage strategies
