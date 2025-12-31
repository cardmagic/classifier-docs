---
title: "LSI Basics"
description: "Learn Latent Semantic Indexing for semantic search and document similarity."
category: lsi
order: 1
---

# Latent Semantic Indexing Basics

Latent Semantic Indexing (LSI) finds relationships between documents based on meaning, not just matching keywords. It uses Singular Value Decomposition (SVD) to discover latent topics in your documents.

## How It Works

1. **Build a term-document matrix**: Each document becomes a vector of word frequencies
2. **Apply SVD**: Decompose the matrix to find underlying topics
3. **Compare in topic space**: Documents with similar topics are semantically related

This means "dog" and "canine" will be considered similar even if they never appear together, because they occur in similar contexts.

## Creating an LSI Index

```ruby
require 'classifier'

lsi = Classifier::LSI.new
```

## Adding Documents

Use hash-style syntax to add documents with categories:

```ruby
# Add with category => item syntax (recommended)
lsi.add("Programming" => "Ruby is a dynamic programming language")
lsi.add("Programming" => "Python emphasizes code readability")

# Add multiple items to the same category
lsi.add("Frameworks" => ["Rails is a web framework", "Django is a Python web framework"])

# Add to multiple categories at once
lsi.add(
  "Frameworks" => ["Rails is a web framework", "Django is for Python"],
  "Libraries" => "React is a JavaScript library"
)

# Legacy API (still works)
lsi.add_item "Ruby is great", :ruby_doc
```

## Finding Related Documents

```ruby
# Find documents similar to one in the index
related = lsi.find_related(:ruby_doc, 3)
# Returns the 3 most similar documents

# Find documents similar to new text
related = lsi.find_related("web development with Ruby", 5)
```

## Semantic Search

Search finds documents that match the meaning of your query:

```ruby
lsi.add_item "Machine learning algorithms", :ml
lsi.add_item "Deep neural networks", :dl
lsi.add_item "Traditional programming approaches", :traditional

results = lsi.search "artificial intelligence methods", 2
# => [:ml, :dl] - even though "AI" wasn't in the documents
```

## Training Data Size Limits

Unlike Bayes and Logistic Regression, LSI does **not** scale well with large datasets. The SVD computation that powers LSI has O(n²) complexity, meaning training time grows quadratically with document count.

### Benchmark: Training Time vs Document Count

| Documents | Build Time | Notes |
|-----------|------------|-------|
| 200 | ~1s | Interactive use |
| 400 | ~10s | Acceptable |
| 600 | ~30s | Getting slow |
| 800 | ~75s | Patience required |
| 1,000+ | Minutes | Consider alternatives |

```ruby
# This is fine for Bayes (50,000 docs trains in seconds)
bayes = Classifier::Bayes.new("Positive", "Negative")
50_000.times { |i| bayes.train("Positive", training_data[i]) }

# But for LSI, 50,000 docs would take hours
lsi = Classifier::LSI.new(auto_rebuild: false)
# Don't do this - O(n²) means 50,000 docs is ~6,000x slower than 200 docs
```

### Why This Matters

The bottleneck is `build_index`, which performs Singular Value Decomposition (SVD) on the entire term-document matrix. This is fundamentally different from Bayes/LogReg which process each document independently.

```ruby
# Bayes: O(n) - each document processed once
bayes.train("Category", document)  # Fast, regardless of corpus size

# LSI: O(n²) - all documents compared to all others
lsi.build_index  # Slow, gets much slower with more docs
```

### Finding Your Optimal Training Size

Run a quick benchmark to find the sweet spot for your hardware:

```ruby
require 'classifier'

[100, 200, 300, 400, 500].each do |count|
  lsi = Classifier::LSI.new(auto_rebuild: false)

  count.times { |i| lsi.add_item("Document #{i} with some content", :"doc_#{i}") }

  start = Time.now
  lsi.build_index
  elapsed = Time.now - start

  puts "#{count} docs: #{elapsed.round(1)}s"
  break if elapsed > 60  # Stop if we exceed your threshold
end
```

### Strategies for Large Datasets

1. **Sample your data**: Often 500-1000 well-chosen documents work as well as 10,000
2. **Use Bayes/LogReg for classification**: Reserve LSI for similarity search
3. **Incremental mode**: Add documents after initial build without full recompute
4. **Hybrid approach**: Use Bayes for initial filtering, LSI for re-ranking top results

```ruby
# Hybrid: Fast Bayes filter + LSI re-ranking
candidates = bayes.classify_top_n(query, 100)  # Fast: narrow to 100
results = lsi.find_related(query, 10, within: candidates)  # Slow but small set
```

### Quality vs Quantity

More data isn't always better with LSI. A focused corpus of 500 high-quality documents often outperforms 5,000 noisy ones:

```ruby
# Better: 500 carefully selected documents
curated_docs = documents.select { |d| d.length > 100 && d.relevant? }
curated_docs.first(500).each { |doc| lsi.add_item(doc) }

# Worse: 5,000 documents including noise
documents.each { |doc| lsi.add_item(doc) }  # Slow AND less accurate
```

## Classification

When you add items with categories, LSI can classify new content:

```ruby
lsi.add("Sports" => ["Defensive strategies in football", "Basketball playoff predictions"])
lsi.add("Finance" => ["Stock market analysis", "Investment portfolio strategies"])

category = lsi.classify "The team's offensive lineup"
# => "Sports"

# Get classification with confidence score
result, confidence = lsi.classify_with_confidence "Investment tips"
# => ["Finance", 0.89]
```

## Auto-Rebuild vs Manual Control

By default, LSI rebuilds its index after every change. For bulk operations, disable this:

```ruby
# Disable auto-rebuild
lsi = Classifier::LSI.new(auto_rebuild: false)

# Add many documents
documents.each { |doc| lsi.add_item(doc) }

# Manually rebuild once
lsi.build_index
```

## Streaming & Batch Training

For large document collections, use batch training with progress tracking:

```ruby
lsi = Classifier::LSI.new(auto_rebuild: false)

# Batch add items by category
lsi.add_batch(
  tech: tech_documents,
  sports: sports_documents,
  batch_size: 500
) do |progress|
  puts "Added #{progress.completed} items (#{progress.rate.round}/sec)"
end

# Build index once after all documents are added
lsi.build_index
```

For files too large to load into memory, stream line-by-line:

```ruby
File.open('corpus.txt', 'r') do |file|
  lsi.train_from_stream(:documents, file, batch_size: 1000) do |progress|
    puts "Processed #{progress.completed} lines"
  end
end

lsi.build_index
```

The streaming API automatically disables auto-rebuild during training and rebuilds the index once at the end.

See the [Streaming Training Tutorial](/docs/tutorials/streaming-training) for checkpoints and resumable training.

## When to Use LSI

**Good for:**
- Finding similar documents
- Semantic search (search by meaning)
- Topic discovery
- Recommendation systems
- Document clustering

**Not ideal for:**
- Simple keyword matching (use regular search)
- Very large document collections (memory intensive)
- When you need exact term matching

## Bayes vs LSI

| Feature | Bayes | LSI |
|---------|-------|-----|
| Speed | Very fast | Slower (SVD computation) |
| Training | Explicit categories | Learns from structure |
| Best for | Classification | Similarity/Search |
| Memory | Low | Higher |

## Example: Document Recommender

```ruby
lsi = Classifier::LSI.new

# Add your document library with categories
lsi.add(
  "Ruby" => ["Introduction to Ruby programming", "Advanced Ruby metaprogramming"],
  "Python" => ["Getting started with Python", "Django web framework guide"],
  "Web" => ["Web development with Rails", "Django web framework guide"]
)

# Recommend documents similar to a query
recommendations = lsi.find_related("Ruby programming basics", 3)
# => ["Introduction to Ruby programming", "Advanced Ruby metaprogramming", ...]

# Or search by keyword
results = lsi.search("web framework", 2)
# => ["Web development with Rails", "Django web framework guide"]
```

## Performance Notes

LSI uses native C extensions for fast SVD computation when available. Check your backend:

```ruby
Classifier::LSI.backend
# => :native (fast) or :ruby (slower fallback)
```

## Next Steps

- [LSI Advanced](/docs/guides/lsi/advanced) - Incremental LSI, SVD tuning, and performance optimization
- [Streaming Training](/docs/tutorials/streaming-training) - Train on large corpora with progress tracking
- [Persistence](/docs/guides/persistence/basics) - Save and load trained indices
