---
title: "Streaming Training"
description: "Train classifiers on large datasets with memory-efficient streaming, batch processing with progress tracking, and checkpoint-based resumable training."
difficulty: intermediate
classifiers: [bayes, lsi, knn, tfidf, logisticregression]
order: 14
---

# Streaming Training

Train classifiers on datasets too large to fit in memory. The streaming API processes data in batches, tracks progress, and supports checkpoints for resumable training.

## What You'll Learn

- Batch training with progress callbacks
- Streaming from files line-by-line
- Checkpoint-based resumable training
- Building a large-scale training pipeline

## Why Streaming?

Traditional training loads everything into memory:

```ruby
# This loads ALL documents into memory first
documents.each { |doc| classifier.train(:spam, doc) }
```

For large corpora (millions of documents, multi-GB files), this is impractical. Streaming processes data incrementally:

```ruby
# Processes 1000 docs at a time, yields progress
classifier.train_batch(:spam, documents, batch_size: 1000) do |progress|
  puts "#{progress.percent}% complete (#{progress.rate.round} docs/sec)"
end
```

## Batch Training

### Basic Batch Training

Process an array in configurable batches:

```ruby
require 'classifier'

classifier = Classifier::Bayes.new('Spam', 'Ham')

spam_docs = load_spam_documents  # Array of strings
ham_docs = load_ham_documents

# Train in batches of 500
classifier.train_batch(:spam, spam_docs, batch_size: 500)
classifier.train_batch(:ham, ham_docs, batch_size: 500)
```

### Progress Tracking

Get detailed progress information during training:

```ruby
classifier.train_batch(:spam, documents, batch_size: 1000) do |progress|
  puts "Progress: #{progress.completed}/#{progress.total}"
  puts "Percent: #{progress.percent}%"
  puts "Rate: #{progress.rate.round(1)} docs/sec"
  puts "ETA: #{progress.eta&.round}s remaining"
  puts "Elapsed: #{progress.elapsed.round(1)}s"
  puts "---"
end
```

The `Progress` object provides:

| Property | Description |
|----------|-------------|
| `completed` | Documents processed so far |
| `total` | Total documents (if known) |
| `percent` | Completion percentage (0-100) |
| `rate` | Processing rate (docs/sec) |
| `eta` | Estimated seconds remaining |
| `elapsed` | Seconds since training started |
| `current_batch` | Current batch number |
| `complete?` | Whether training is done |

### Multi-Category Batch Training

Train multiple categories in one call:

```ruby
classifier.train_batch(
  spam: spam_documents,
  ham: ham_documents,
  batch_size: 1000
) do |progress|
  puts "#{progress.percent}% complete"
end
```

## Stream Training from Files

For files too large to load into memory, stream line-by-line:

```ruby
# Each line in the file is treated as one document
File.open('spam_corpus.txt', 'r') do |file|
  classifier.train_from_stream(:spam, file, batch_size: 1000) do |progress|
    puts "Processed #{progress.completed} lines"
  end
end

File.open('ham_corpus.txt', 'r') do |file|
  classifier.train_from_stream(:ham, file, batch_size: 1000)
end
```

### StringIO for Testing

Use `StringIO` for testing without files:

```ruby
require 'stringio'

corpus = StringIO.new(<<~CORPUS)
  buy now cheap viagra
  free money limited offer
  act now don't miss out
  click here for prizes
CORPUS

classifier.train_from_stream(:spam, corpus, batch_size: 2) do |progress|
  puts "Batch #{progress.current_batch}: #{progress.completed} docs"
end
```

## Checkpoints for Resumable Training

Long training runs can be interrupted. Checkpoints save progress so you can resume later.

### Saving Checkpoints

```ruby
classifier = Classifier::Bayes.new('Spam', 'Ham')
classifier.storage = Classifier::Storage::File.new(path: 'model.json')

# Train first batch
classifier.train_batch(:spam, spam_docs_part1, batch_size: 1000)
classifier.save_checkpoint('phase1')

# Train second batch
classifier.train_batch(:spam, spam_docs_part2, batch_size: 1000)
classifier.save_checkpoint('phase2')

# Train third batch
classifier.train_batch(:ham, ham_docs, batch_size: 1000)
classifier.save_checkpoint('complete')

# Save final model
classifier.save
```

### Resuming from Checkpoints

```ruby
storage = Classifier::Storage::File.new(path: 'model.json')

# Resume from where we left off
classifier = Classifier::Bayes.load_checkpoint(
  storage: storage,
  checkpoint_id: 'phase2'
)

# Continue training
classifier.train_batch(:ham, remaining_docs, batch_size: 1000)
classifier.save
```

### Managing Checkpoints

```ruby
# List available checkpoints
checkpoints = classifier.list_checkpoints
puts "Available: #{checkpoints.join(', ')}"
# => "Available: phase1, phase2, complete"

# Delete old checkpoints to save disk space
classifier.delete_checkpoint('phase1')
classifier.delete_checkpoint('phase2')
```

## Practical Example: Email Corpus Trainer

Build a training pipeline for a large email corpus:

```ruby
require 'classifier'

class EmailCorpusTrainer
  BATCH_SIZE = 5000
  CHECKPOINT_INTERVAL = 50_000

  def initialize(model_path)
    @model_path = model_path
    @storage = Classifier::Storage::File.new(path: model_path)
    @classifier = nil
    @total_trained = 0
  end

  def train(spam_file:, ham_file:, resume_from: nil)
    @classifier = if resume_from
      puts "Resuming from checkpoint: #{resume_from}"
      Classifier::Bayes.load_checkpoint(storage: @storage, checkpoint_id: resume_from)
    else
      c = Classifier::Bayes.new('Spam', 'Ham')
      c.storage = @storage
      c
    end

    puts "Training spam from #{spam_file}..."
    train_from_file(:spam, spam_file)

    puts "\nTraining ham from #{ham_file}..."
    train_from_file(:ham, ham_file)

    puts "\nSaving final model..."
    @classifier.save

    cleanup_checkpoints
    puts "Training complete! Total: #{@total_trained} documents"
  end

  private

  def train_from_file(category, path)
    File.open(path, 'r') do |file|
      @classifier.train_from_stream(category, file, batch_size: BATCH_SIZE) do |progress|
        @total_trained = progress.completed

        # Show progress
        print "\r  #{progress.completed} docs (#{progress.rate.round} docs/sec)"

        # Save checkpoint periodically
        if progress.completed % CHECKPOINT_INTERVAL == 0
          checkpoint_id = "#{category}_#{progress.completed}"
          @classifier.save_checkpoint(checkpoint_id)
          puts "\n  Checkpoint saved: #{checkpoint_id}"
        end
      end
    end
    puts # newline after progress
  end

  def cleanup_checkpoints
    @classifier.list_checkpoints.each do |checkpoint|
      @classifier.delete_checkpoint(checkpoint)
    end
    puts "Cleaned up intermediate checkpoints"
  end
end

# Usage
trainer = EmailCorpusTrainer.new('email_classifier.json')
trainer.train(
  spam_file: 'data/spam_corpus.txt',
  ham_file: 'data/ham_corpus.txt'
)

# Or resume interrupted training
trainer.train(
  spam_file: 'data/spam_corpus.txt',
  ham_file: 'data/ham_corpus.txt',
  resume_from: 'spam_50000'
)
```

## Streaming with Other Classifiers

All classifiers support streaming:

### LSI Streaming

```ruby
lsi = Classifier::LSI.new(auto_rebuild: false)

# Batch add items by category
lsi.add_batch(
  tech: tech_documents,
  sports: sports_documents,
  batch_size: 500
) do |progress|
  puts "Added #{progress.completed} items"
end

# Index is automatically built after add_batch completes
# (if auto_rebuild was true, it rebuilds; otherwise call build_index)
lsi.build_index
```

### KNN Streaming

```ruby
knn = Classifier::KNN.new(k: 5)

# Batch training
knn.train_batch(
  tech: tech_docs,
  sports: sports_docs,
  batch_size: 1000
) do |progress|
  puts "#{progress.percent}% complete"
end
```

### Logistic Regression Streaming

Logistic Regression requires an explicit `fit()` call after streaming training:

```ruby
classifier = Classifier::LogisticRegression.new([:spam, :ham])

# Stream training data
File.open('spam_corpus.txt', 'r') do |file|
  classifier.train_from_stream(:spam, file, batch_size: 1000) do |progress|
    puts "#{progress.completed} spam docs"
  end
end

File.open('ham_corpus.txt', 'r') do |file|
  classifier.train_from_stream(:ham, file, batch_size: 1000) do |progress|
    puts "#{progress.completed} ham docs"
  end
end

# IMPORTANT: Must call fit() before classification
puts "Fitting model..."
classifier.fit

# Now ready to classify
classifier.classify("New message")
```

You can also use batch training with keyword arguments:

```ruby
classifier.train_batch(
  spam: spam_documents,
  ham: ham_documents,
  batch_size: 500
) do |progress|
  puts "#{progress.percent}% complete"
end

classifier.fit  # Don't forget!
```

### TF-IDF Streaming

```ruby
tfidf = Classifier::TFIDF.new

# Fit vocabulary from stream
File.open('corpus.txt', 'r') do |file|
  tfidf.fit_from_stream(file, batch_size: 1000) do |progress|
    puts "Processed #{progress.completed} documents"
  end
end
```

## Progress Display Utilities

Build a reusable progress display:

```ruby
class TrainingProgress
  def initialize(label)
    @label = label
    @last_update = Time.now
  end

  def update(progress)
    # Update at most once per second
    return if Time.now - @last_update < 1

    @last_update = Time.now

    bar = progress_bar(progress.percent || 0)
    rate = "#{progress.rate.round(1)} docs/sec"
    eta = progress.eta ? "ETA: #{format_time(progress.eta)}" : ""

    print "\r#{@label}: #{bar} #{progress.percent&.round(1) || '?'}% | #{rate} | #{eta}    "
  end

  def finish
    puts "\n#{@label}: Complete!"
  end

  private

  def progress_bar(percent, width: 30)
    filled = (percent / 100.0 * width).round
    empty = width - filled
    "[#{'=' * filled}#{' ' * empty}]"
  end

  def format_time(seconds)
    if seconds < 60
      "#{seconds.round}s"
    elsif seconds < 3600
      "#{(seconds / 60).round}m"
    else
      "#{(seconds / 3600).round(1)}h"
    end
  end
end

# Usage
progress_display = TrainingProgress.new("Training spam")

classifier.train_batch(:spam, documents, batch_size: 1000) do |progress|
  progress_display.update(progress)
end

progress_display.finish
```

## Performance Tips

1. **Choose appropriate batch sizes**: Larger batches = fewer callbacks, but more memory. Start with 1000-5000.

2. **Use checkpoints for long jobs**: Save every N documents so crashes don't lose hours of work.

3. **Stream from compressed files**: Combine with gzip for large corpora:
   ```ruby
   require 'zlib'

   Zlib::GzipReader.open('corpus.txt.gz') do |gz|
     classifier.train_from_stream(:spam, gz, batch_size: 1000)
   end
   ```

4. **Monitor memory**: Use batch training even for in-memory arrays to keep memory predictable.

5. **Clean up checkpoints**: Delete intermediate checkpoints after successful completion.

## Error Handling

Handle interruptions gracefully:

```ruby
begin
  classifier.train_batch(:spam, documents, batch_size: 1000) do |progress|
    puts "#{progress.percent}% complete"
  end
rescue Interrupt
  puts "\nInterrupted! Saving checkpoint..."
  classifier.save_checkpoint('interrupted')
  puts "Resume later with checkpoint 'interrupted'"
  raise
end
```

## Next Steps

- [Persistence Guide](/docs/guides/persistence/basics) - Storage backends and dirty tracking
- [Real-time Pipeline](/docs/tutorials/realtime-pipeline) - Production classification systems
- [Ensemble Classifier](/docs/tutorials/ensemble-classifier) - Combine multiple classifiers
