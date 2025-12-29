---
title: "Persistence Framework"
description: "Save and load classifiers with pluggable storage backends."
category: persistence
order: 1
---

# Persistence Framework

The classifier gem provides a flexible persistence framework that lets you save and load trained classifiers using pluggable storage backends. Whether you need simple file storage, in-memory caching, or distributed storage like Redis, the API remains consistent.

## Quick Start

```ruby
require 'classifier'

# Create and train a classifier
classifier = Classifier::Bayes.new 'Spam', 'Ham'
classifier.train(spam: "Buy cheap products now!")
classifier.train(ham: "Meeting scheduled for tomorrow")

# Configure storage
classifier.storage = Classifier::Storage::File.new(path: "spam_filter.json")

# Save to storage
classifier.save

# Later, load it back
loaded = Classifier::Bayes.load(storage: classifier.storage)
loaded.classify "Limited time offer!"
# => "Spam"
```

## Storage Backends

The gem includes two built-in storage backends, with a simple protocol for creating custom ones.

### File Storage

Persist classifiers to JSON files on disk:

```ruby
storage = Classifier::Storage::File.new(path: "/var/models/classifier.json")

classifier.storage = storage
classifier.save

# The file is human-readable JSON
File.read("/var/models/classifier.json")
# => {"type":"bayes","categories":{"Spam":{...},...}
```

File storage is ideal for:
- Single-server deployments
- Development and testing
- Backup and versioning (commit models to git)
- Serverless functions with mounted storage

### Memory Storage

Keep classifiers in memory for testing or ephemeral use:

```ruby
storage = Classifier::Storage::Memory.new

classifier.storage = storage
classifier.save

# Data persists only for the lifetime of the storage object
loaded = Classifier::Bayes.load(storage: storage)
```

Memory storage is ideal for:
- Unit tests and integration tests
- Caching layers
- Ephemeral processing pipelines

## The Storage API

Both Bayes and LSI classifiers share the same persistence API:

### Saving

```ruby
# Save to configured storage
classifier.storage = Classifier::Storage::File.new(path: "model.json")
classifier.save

# Or save directly to a file (legacy API)
classifier.save_to_file("model.json")
```

### Loading

```ruby
# Load with storage pre-configured
storage = Classifier::Storage::File.new(path: "model.json")
classifier = Classifier::Bayes.load(storage: storage)
classifier.storage  # => #<Classifier::Storage::File...>

# Or load directly from file (legacy API)
classifier = Classifier::Bayes.load_from_file("model.json")
classifier.storage  # => nil
```

### Dirty Tracking

The classifier tracks whether it has unsaved changes:

```ruby
classifier = Classifier::Bayes.new :a, :b
classifier.dirty?
# => false

classifier.train(a: "some text")
classifier.dirty?
# => true

classifier.save
classifier.dirty?
# => false
```

### Reloading

Discard in-memory changes and reload from storage:

```ruby
classifier.train(spam: "new training data")
classifier.dirty?
# => true

# Safe reload - raises if there are unsaved changes
classifier.reload
# => raises Classifier::UnsavedChangesError

# Force reload - discards unsaved changes
classifier.reload!
classifier.dirty?
# => false
```

## Creating Custom Storage Backends

Implement the `Classifier::Storage::Base` protocol to create custom backends:

```ruby
class RedisStorage < Classifier::Storage::Base
  def initialize(redis:, key:)
    super()
    @redis = redis
    @key = key
  end

  def write(data)
    @redis.set(@key, data)
  end

  def read
    @redis.get(@key)
  end

  def delete
    @redis.del(@key)
  end

  def exists?
    @redis.exists?(@key)
  end
end
```

Use your custom backend:

```ruby
require 'redis'

redis = Redis.new(url: ENV['REDIS_URL'])
storage = RedisStorage.new(redis: redis, key: "classifier:spam_filter")

classifier.storage = storage
classifier.save
```

### Storage Protocol

Your storage class must implement these four methods:

| Method | Signature | Description |
|--------|-----------|-------------|
| `write` | `(String) -> void` | Save serialized classifier data |
| `read` | `() -> String?` | Load data, return nil if not found |
| `delete` | `() -> void` | Remove stored data |
| `exists?` | `() -> bool` | Check if data exists |

## Example: PostgreSQL Storage

```ruby
class PostgresStorage < Classifier::Storage::Base
  def initialize(connection:, table: 'classifiers', id:)
    super()
    @conn = connection
    @table = table
    @id = id
  end

  def write(data)
    @conn.exec_params(
      "INSERT INTO #{@table} (id, data, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (id) DO UPDATE SET data = $2, updated_at = NOW()",
      [@id, data]
    )
  end

  def read
    result = @conn.exec_params(
      "SELECT data FROM #{@table} WHERE id = $1",
      [@id]
    )
    result.ntuples > 0 ? result[0]['data'] : nil
  end

  def delete
    @conn.exec_params("DELETE FROM #{@table} WHERE id = $1", [@id])
  end

  def exists?
    result = @conn.exec_params(
      "SELECT 1 FROM #{@table} WHERE id = $1",
      [@id]
    )
    result.ntuples > 0
  end
end
```

## Example: S3 Storage

```ruby
class S3Storage < Classifier::Storage::Base
  def initialize(bucket:, key:, client: Aws::S3::Client.new)
    super()
    @bucket = bucket
    @key = key
    @client = client
  end

  def write(data)
    @client.put_object(bucket: @bucket, key: @key, body: data)
  end

  def read
    @client.get_object(bucket: @bucket, key: @key).body.read
  rescue Aws::S3::Errors::NoSuchKey
    nil
  end

  def delete
    @client.delete_object(bucket: @bucket, key: @key)
  end

  def exists?
    @client.head_object(bucket: @bucket, key: @key)
    true
  rescue Aws::S3::Errors::NotFound
    false
  end
end
```

## Error Handling

The persistence framework defines specific exceptions:

```ruby
# Base error class
Classifier::Error

# Raised when reload would discard unsaved changes
Classifier::UnsavedChangesError

# Raised when storage operations fail
Classifier::StorageError
```

Handle errors appropriately:

```ruby
begin
  classifier.reload
rescue Classifier::UnsavedChangesError
  # Prompt user or auto-save
  classifier.save
  classifier.reload
rescue Classifier::StorageError => e
  # Storage backend failed
  logger.error "Failed to reload: #{e.message}"
end
```

## Best Practices

### 1. Configure Storage at Initialization

```ruby
def create_classifier
  classifier = Classifier::Bayes.new 'Spam', 'Ham'
  classifier.storage = Classifier::Storage::File.new(
    path: Rails.root.join('models', 'spam_filter.json').to_s
  )
  classifier
end
```

### 2. Save After Batch Training

```ruby
# Don't save after every training example
emails.each do |email|
  classifier.train(email.label, email.body)
end

# Save once at the end
classifier.save
```

### 3. Use Memory Storage in Tests

```ruby
RSpec.describe SpamFilter do
  let(:storage) { Classifier::Storage::Memory.new }
  let(:classifier) do
    c = Classifier::Bayes.new 'Spam', 'Ham'
    c.storage = storage
    c
  end

  it "persists training" do
    classifier.train(spam: "buy now")
    classifier.save

    loaded = Classifier::Bayes.load(storage: storage)
    expect(loaded.classify("buy now")).to eq("Spam")
  end
end
```

### 4. Version Your Models

```ruby
class VersionedStorage < Classifier::Storage::File
  def initialize(path:, version:)
    super(path: "#{path}.v#{version}.json")
    @version = version
  end
end

# Deploy new model versions without downtime
storage_v1 = VersionedStorage.new(path: "spam_filter", version: 1)
storage_v2 = VersionedStorage.new(path: "spam_filter", version: 2)
```

## Works with Both Classifiers

The persistence API is identical for Bayes and LSI:

```ruby
# Bayes
bayes = Classifier::Bayes.new :a, :b
bayes.storage = Classifier::Storage::File.new(path: "bayes.json")
bayes.train(a: "text")
bayes.save

# LSI
lsi = Classifier::LSI.new
lsi.storage = Classifier::Storage::File.new(path: "lsi.json")
lsi.add_item "document", :category
lsi.save
```

## Next Steps

- [Bayes Basics](/docs/guides/bayes/basics) - Learn about Bayesian classification
- [LSI Basics](/docs/guides/lsi/basics) - Explore semantic indexing
- [Real-time Pipeline](/docs/tutorials/realtime-pipeline) - Build a production-ready classification pipeline
