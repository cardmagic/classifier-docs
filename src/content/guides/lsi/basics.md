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
require 'classifier-reborn'

lsi = Classifier::LSI.new
```

## Adding Documents

Each item needs content (the text to analyze) and optionally a key (for retrieval):

```ruby
# Add with a key
lsi.add_item "Ruby is a dynamic programming language", :ruby_doc

# Add with the text itself as the key
lsi.add_item "Python emphasizes code readability"

# Add with a category for classification
lsi.add_item "Rails is a web framework", :frameworks
lsi.add_item "Django is a Python web framework", :frameworks
lsi.add_item "React is a JavaScript library", :libraries
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
lsi.add_item "Defensive strategies in football", :sports
lsi.add_item "Basketball playoff predictions", :sports
lsi.add_item "Stock market analysis", :finance
lsi.add_item "Investment portfolio strategies", :finance

category = lsi.classify "The team's offensive lineup"
# => :sports
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

# Add your document library
lsi.add_item "Introduction to Ruby programming", :ruby_intro
lsi.add_item "Advanced Ruby metaprogramming", :ruby_advanced
lsi.add_item "Getting started with Python", :python_intro
lsi.add_item "Web development with Rails", :rails
lsi.add_item "Django web framework guide", :django

# User just read the Ruby intro
current_doc = :ruby_intro

# Recommend similar documents
recommendations = lsi.find_related(current_doc, 3)
# => [:ruby_advanced, :rails, ...] - related by topic
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
