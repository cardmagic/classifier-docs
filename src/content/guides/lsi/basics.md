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

- [Semantic Search](/docs/guides/lsi/semantic-search) - Build a search engine
- [Clustering](/docs/guides/lsi/clustering) - Group similar documents
- [Tuning Parameters](/docs/guides/lsi/tuning) - Optimize for your use case
