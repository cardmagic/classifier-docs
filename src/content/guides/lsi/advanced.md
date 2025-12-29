---
title: "LSI Advanced"
description: "Incremental LSI, SVD tuning, and advanced patterns for high-performance semantic indexing."
category: lsi
order: 2
---

# LSI Advanced

This guide covers advanced LSI features for production use: incremental updates, SVD tuning, and performance optimization.

## Incremental LSI

Standard LSI rebuilds the entire SVD when you add documents—expensive for large indices. Incremental mode uses Brand's algorithm to add documents in O(k²) time instead of O(mn²):

```ruby
lsi = Classifier::LSI.new(incremental: true)

# Add initial documents and build the index
lsi.add(tech: ["Ruby is elegant", "Python is popular"])
lsi.build_index

# These use Brand's algorithm—no full rebuild
lsi.add(tech: "Go is fast")
lsi.add(tech: "Rust is safe")
```

After the first `build_index`, new documents are projected onto the existing semantic space and the SVD is updated incrementally.

### When to Use Incremental Mode

**Good for:**
- Streaming data (logs, feeds, user content)
- Growing document collections
- Real-time indexing requirements
- Memory-constrained environments

**Not ideal for:**
- Small, static document sets (full SVD is fast enough)
- When documents change the vocabulary significantly
- When you need maximum precision

### How It Works

Brand's algorithm maintains the U matrix (left singular vectors) from the SVD decomposition. When a new document arrives:

1. **Project**: Compute how the document maps to existing topics
2. **Residual**: Find the component orthogonal to known topics
3. **Update**: If there's a new direction, grow the rank; otherwise, update in place
4. **Truncate**: Keep only the top-k singular values

This avoids recomputing the full SVD, making adds ~400x faster for large indices.

### Checking Incremental Status

```ruby
lsi = Classifier::LSI.new(incremental: true, auto_rebuild: false)
lsi.add(dogs: ["Dogs bark", "Puppies play"])

lsi.incremental_enabled?  # => false (not yet built)

lsi.build_index

lsi.incremental_enabled?  # => true (ready for incremental adds)
lsi.current_rank          # => 2 (number of semantic dimensions)
```

## Controlling SVD Rank

The `max_rank` parameter limits how many semantic dimensions to keep:

```ruby
# Keep at most 50 dimensions
lsi = Classifier::LSI.new(incremental: true, max_rank: 50)
```

Lower rank means:
- Faster operations
- Less memory
- More aggressive dimensionality reduction (may lose nuance)

Higher rank means:
- Better precision
- More memory
- Slower incremental updates

### Inspecting Singular Values

Use `singular_value_spectrum` to understand your semantic space:

```ruby
lsi.build_index

spectrum = lsi.singular_value_spectrum
spectrum.each do |entry|
  puts "Dim #{entry[:dimension]}: #{(entry[:cumulative_percentage] * 100).round}% variance"
end

# Find how many dimensions capture 90% of variance
dims_90 = spectrum.find_index { |e| e[:cumulative_percentage] >= 0.90 }
puts "#{dims_90 + 1} dimensions capture 90% of variance"
```

This helps tune `max_rank`—if 20 dimensions capture 95% of variance, setting `max_rank: 25` gives good results with minimal overhead.

## Mode Management

### Enabling Incremental Mode Later

Start without incremental mode, then enable it:

```ruby
lsi = Classifier::LSI.new(auto_rebuild: false)

# Bulk load
documents.each { |doc| lsi.add_item(doc, :category) }
lsi.build_index

# Switch to incremental for future adds
lsi.enable_incremental_mode!(max_rank: 100)
lsi.build_index(force: true)  # Rebuild to capture U matrix

# Now adds are incremental
lsi.add(category: "New document")
```

### Disabling Incremental Mode

If classification quality degrades, switch back to full rebuilds:

```ruby
lsi.disable_incremental_mode!

# Next add triggers full SVD
lsi.add(category: "Document requiring full rebuild")
```

### Vocabulary Growth

Incremental mode automatically falls back to full rebuild when vocabulary grows more than 20%. This prevents quality degradation from too many out-of-vocabulary terms:

```ruby
lsi = Classifier::LSI.new(incremental: true, auto_rebuild: false)
lsi.add(tech: ["Ruby code", "Python code"])
lsi.build_index

lsi.incremental_enabled?  # => true

# Add document with many new words
lsi.add(tech: "Quantum computing uses qubits for superposition entanglement")

# Vocabulary grew significantly—fell back to full rebuild
lsi.incremental_enabled?  # => false
```

Re-enable with `enable_incremental_mode!` and `build_index(force: true)` if needed.

## Streaming with Incremental Mode

Combine streaming ingestion with incremental updates for live data:

```ruby
lsi = Classifier::LSI.new(incremental: true, auto_rebuild: false)

# Initial corpus
File.open('initial_corpus.txt') do |file|
  lsi.train_from_stream(:documents, file, batch_size: 1000)
end
lsi.build_index

# Process live stream incrementally
live_feed.each do |message|
  lsi.add(documents: message.text)

  # Classify in real-time
  category = lsi.classify(message.text)
  route_message(message, category)
end
```

### Periodic Full Rebuilds

For long-running systems, schedule periodic full rebuilds to maintain quality:

```ruby
class LSIManager
  def initialize
    @lsi = Classifier::LSI.new(incremental: true)
    @adds_since_rebuild = 0
  end

  def add_document(text, category)
    @lsi.add(category => text)
    @adds_since_rebuild += 1

    # Full rebuild every 10,000 documents
    if @adds_since_rebuild >= 10_000
      rebuild!
    end
  end

  def rebuild!
    @lsi.disable_incremental_mode!
    @lsi.build_index(force: true)
    @lsi.enable_incremental_mode!
    @adds_since_rebuild = 0
  end
end
```

## Build Index Cutoff

The `cutoff` parameter controls how many singular values to keep during SVD:

```ruby
# Keep top 50% of singular values (more aggressive reduction)
lsi.build_index(0.50)

# Keep top 90% of singular values (preserve more detail)
lsi.build_index(0.90)

# Default is 0.75
lsi.build_index
```

Lower cutoff = fewer dimensions = faster but less precise.

## Performance Comparison

| Operation | Standard LSI | Incremental LSI |
|-----------|-------------|-----------------|
| Initial build | O(mn²) | O(mn²) |
| Add document | O(mn²) rebuild | O(k²) update |
| Memory | Term-doc matrix | Term-doc + U matrix |
| Classification | Same | Same |
| Search | Same | Same |

For a 10,000-document index with 5,000 terms and k=100:
- Standard add: ~250ms (full SVD)
- Incremental add: ~0.6ms (Brand's update)

## Best Practices

1. **Start with full SVD**: Build your initial index without incremental mode for best quality
2. **Enable incremental for growth**: Switch to incremental mode after the initial build
3. **Monitor quality**: Track classification accuracy; rebuild if it degrades
4. **Tune max_rank**: Use `singular_value_spectrum` to find the right balance
5. **Handle vocabulary growth**: Expect automatic fallbacks when content changes significantly
6. **Schedule rebuilds**: For production systems, rebuild periodically (daily/weekly)

## Next Steps

- [LSI Basics](/docs/guides/lsi/basics) - Core LSI concepts and API
- [Streaming Training](/docs/tutorials/streaming-training) - Process large datasets efficiently
- [Persistence](/docs/guides/persistence/basics) - Save and load trained indices
