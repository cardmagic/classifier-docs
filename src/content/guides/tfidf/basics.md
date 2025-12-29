---
title: "TF-IDF Basics"
description: "Transform text into weighted feature vectors with Term Frequency-Inverse Document Frequency."
category: tfidf
order: 1
---

# TF-IDF Basics

TF-IDF (Term Frequency-Inverse Document Frequency) transforms text into numerical feature vectors. It's the foundation for most classic text classification and is useful for feature extraction, document similarity, and search.

## How It Works

TF-IDF combines two metrics:

1. **Term Frequency (TF)**: How often a word appears in a document
2. **Inverse Document Frequency (IDF)**: How rare a word is across all documents

Words that appear frequently in one document but rarely in others get high scores. Common words like "the" get low scores because they appear everywhere.

```
TF-IDF = TF × IDF
```

## Creating a Vectorizer

```ruby
require 'classifier'

tfidf = Classifier::TFIDF.new
```

## Fitting and Transforming

The vectorizer needs to learn the vocabulary from your corpus first:

```ruby
# Fit: learn vocabulary and IDF weights
tfidf.fit([
  "Dogs are great pets",
  "Cats are independent",
  "Birds can fly"
])

# Transform: convert new text to TF-IDF vector
vector = tfidf.transform("Dogs are loyal")
# => {:dog=>0.7071..., :loyal=>0.7071...}

# Fit and transform in one step
vectors = tfidf.fit_transform(documents)
```

## Understanding the Output

The transform method returns a hash of stemmed terms to TF-IDF weights:

```ruby
vector = tfidf.transform("Dogs are loyal pets")
# => {:dog=>0.5, :loyal=>0.7, :pet=>0.5}
```

- Keys are stemmed words (e.g., "dogs" → :dog)
- Values are L2-normalized TF-IDF weights
- Common words (stopwords) are filtered out
- The vector magnitude is always 1.0

## Configuration Options

### Vocabulary Filtering

Filter terms by how often they appear across documents:

```ruby
tfidf = Classifier::TFIDF.new(
  min_df: 2,      # Must appear in at least 2 documents
  max_df: 0.95    # Must appear in at most 95% of documents
)
```

Use integers for absolute counts, floats for proportions:

```ruby
min_df: 5      # At least 5 documents
min_df: 0.01   # At least 1% of documents
max_df: 100    # At most 100 documents
max_df: 0.90   # At most 90% of documents
```

### Sublinear TF Scaling

Use logarithmic term frequency to reduce the impact of very frequent terms:

```ruby
tfidf = Classifier::TFIDF.new(sublinear_tf: true)
# Uses 1 + log(tf) instead of raw tf
```

This helps when a word appearing 10 times shouldn't be 10x more important than appearing once.

### N-grams

Extract word pairs (bigrams) or longer sequences:

```ruby
# Unigrams and bigrams
tfidf = Classifier::TFIDF.new(ngram_range: [1, 2])

tfidf.fit(["quick brown fox", "lazy brown dog"])
tfidf.vocabulary.keys
# => [:quick, :brown, :fox, :lazi, :dog, :quick_brown, :brown_fox, :lazi_brown, :brown_dog]

# Bigrams only
tfidf = Classifier::TFIDF.new(ngram_range: [2, 2])

# Unigrams through trigrams
tfidf = Classifier::TFIDF.new(ngram_range: [1, 3])
```

## Inspecting the Vectorizer

```ruby
tfidf.fit(documents)

tfidf.vocabulary      # => {:dog=>0, :cat=>1, :bird=>2, ...}
tfidf.idf             # => {:dog=>1.405, :cat=>1.405, ...}
tfidf.feature_names   # => [:dog, :cat, :bird, ...] (in index order)
tfidf.num_documents   # => 3
tfidf.fitted?         # => true
```

## Streaming from Files

For large corpora that don't fit in memory, fit from a file stream:

```ruby
tfidf = Classifier::TFIDF.new

# Fit vocabulary from stream (one document per line)
File.open('corpus.txt', 'r') do |file|
  tfidf.fit_from_stream(file, batch_size: 1000) do |progress|
    puts "Processed #{progress.completed} documents (#{progress.rate.round}/sec)"
  end
end

# Now transform new documents
vector = tfidf.transform("new document text")
```

The streaming API processes the file line-by-line, building the vocabulary and IDF weights without loading the entire corpus into memory.

See the [Streaming Training Tutorial](/docs/tutorials/streaming-training) for more details on streaming and progress tracking.

## When to Use TF-IDF

**Good for:**
- Feature extraction for machine learning
- Document similarity and search
- Keyword extraction
- Text preprocessing for other classifiers

**Not ideal for:**
- When word order matters (use n-grams or other methods)
- Very short texts (tweets, titles)
- When you need semantic understanding (use LSI instead)

## Example: Document Similarity

```ruby
tfidf = Classifier::TFIDF.new

documents = [
  "Ruby is a programming language",
  "Python is also a programming language",
  "Dogs are great pets",
  "Cats are independent animals"
]

vectors = tfidf.fit_transform(documents)

# Calculate cosine similarity between documents
def cosine_similarity(v1, v2)
  shared_keys = v1.keys & v2.keys
  return 0.0 if shared_keys.empty?

  shared_keys.sum { |k| v1[k] * v2[k] }
end

# Compare first two documents (both about programming)
similarity = cosine_similarity(vectors[0], vectors[1])
# => ~0.7 (high similarity)

# Compare programming doc with pets doc
similarity = cosine_similarity(vectors[0], vectors[2])
# => ~0.0 (no similarity)
```

## Example: Keyword Extraction

```ruby
tfidf = Classifier::TFIDF.new(sublinear_tf: true)

# Fit on your corpus
tfidf.fit(all_documents)

# Extract keywords from a specific document
vector = tfidf.transform(target_document)

# Top 5 keywords by TF-IDF weight
keywords = vector.sort_by { |_, weight| -weight }.first(5).map(&:first)
```

## Serialization

Save and load your fitted vectorizer:

```ruby
# Save to JSON
json = tfidf.to_json
File.write("vectorizer.json", json)

# Load from JSON
loaded = Classifier::TFIDF.from_json(File.read("vectorizer.json"))
loaded.transform("new document")

# Or use Marshal
data = Marshal.dump(tfidf)
loaded = Marshal.load(data)
```

## Using with Other Classifiers

TF-IDF vectors can be used as features for other classifiers:

```ruby
# Extract features
tfidf = Classifier::TFIDF.new(min_df: 2, sublinear_tf: true)
tfidf.fit(training_documents)

# Use vectors as input to your classifier
training_vectors = training_documents.map { |doc| tfidf.transform(doc) }
test_vector = tfidf.transform(new_document)
```

## Next Steps

- [Streaming Training](/docs/tutorials/streaming-training) - Train on large datasets with progress tracking
- [LSI Basics](/docs/guides/lsi/basics) - Semantic analysis using SVD
- [Persistence](/docs/guides/persistence/basics) - Save and load fitted vectorizers
