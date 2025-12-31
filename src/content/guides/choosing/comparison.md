---
title: "Classifier Comparison"
description: "Compare all classifiers side-by-side to choose the right one for your use case."
category: choosing
order: 1
---

# Classifier Comparison Guide

Not sure which classifier to use? This guide compares all four classifiers across accuracy, speed, storage, and capabilities to help you make the right choice.

## Quick Decision Guide

```
Need real-time classification (<1ms)?     → Naive Bayes or Logistic Regression
Need to find similar documents?           → LSI or KNN
Need semantic search?                     → LSI
Need the best classification accuracy?    → Logistic Regression
Have very little training data (<500)?    → Naive Bayes
Need feature importance / explainability? → Logistic Regression
Want the simplest solution?               → Naive Bayes
```

## At a Glance

| Classifier | Best For | Speed | Accuracy |
|------------|----------|-------|----------|
| **Naive Bayes** | Fast classification, streaming data | Very Fast | Good |
| **Logistic Regression** | Best accuracy with calibrated probabilities | Very Fast | Better |
| **KNN** | Classification + finding similar documents | Slow | Good |
| **LSI** | Semantic search, clustering, similarity | Slow | Fair |

## Detailed Comparison

### Primary Purpose

| Classifier | Primary Use | Classification | Semantic Search | Find Similar | Clustering |
|------------|-------------|----------------|-----------------|--------------|------------|
| **Naive Bayes** | Classification | Excellent | No | No | No |
| **Logistic Regression** | Classification | Excellent | No | No | No |
| **KNN** | Classification | Good | Via LSI | Yes | No |
| **LSI** | Similarity/Search | Fair | Excellent | Excellent | Yes |

### Typical Accuracy

| Classifier | Accuracy Range | Calibrated Probabilities |
|------------|----------------|-------------------------|
| **Naive Bayes** | 85-92% | No (log-odds) |
| **Logistic Regression** | 88-94% | Yes (softmax) |
| **KNN** | 82-90% | Partial (distance-based) |
| **LSI** | 80-88% | No |

### Training Performance

| Metric | Naive Bayes | Logistic Regression | KNN | LSI |
|--------|-------------|---------------------|-----|-----|
| **Speed** | Very Fast | Medium | Fast | Medium-Slow |
| **10K documents** | ~0.1-0.5s | ~2-10s | ~1-3s | ~2-10s |
| **100K documents** | ~1-5s | ~30-120s | ~10-30s | ~30-120s |
| **Incremental training** | Yes | No | Yes | Partial |
| **Memory usage** | Low | Medium | Medium | Medium-High |

### Classification Performance

| Metric | Naive Bayes | Logistic Regression | KNN | LSI |
|--------|-------------|---------------------|-----|-----|
| **Speed** | Very Fast | Very Fast | Slow | Slow |
| **Per document** | ~0.05ms | ~0.05ms | ~15ms | ~10-30ms |
| **Throughput** | ~100K/sec | ~100K/sec | ~100-1K/sec | ~50-500/sec |
| **Scales with data size** | No | No | Yes (slower) | Yes (slower) |

### Storage Requirements

| Metric | Naive Bayes | Logistic Regression | KNN | LSI |
|--------|-------------|---------------------|-----|-----|
| **Small model** | 10-100 KB | 50-200 KB | 1-10 MB | 1-10 MB |
| **Large model** | 1-10 MB | 5-20 MB | 50-500 MB | 50-500 MB |
| **Stores training data** | No | No | Yes | Yes |
| **Runtime memory** | Low | Low | High | High |

### Robustness

| Scenario | Naive Bayes | Logistic Regression | KNN | LSI |
|----------|-------------|---------------------|-----|-----|
| **Small training set (<500)** | Good | Fair | Poor | Poor |
| **Imbalanced classes** | Fair | Good | Poor | Fair |
| **Noise tolerance** | Moderate | Moderate | Low | Moderate |
| **High dimensionality** | Excellent | Good | Poor | Excellent |
| **Overfitting risk** | Low | Low | Medium | Low-Medium |

### Unique Capabilities

| Capability | Bayes | LogReg | KNN | LSI |
|------------|-------|--------|-----|-----|
| **Feature importance** | Implicit | Yes | No | No |
| **Semantic search** | No | No | No | Yes |
| **Find related docs** | No | No | Yes | Yes |
| **Document clustering** | No | No | No | Yes |
| **Synonym handling** | No | No | Via LSI | Yes |
| **Online learning** | Yes | No | Yes | Partial |
| **Untraining** | Yes | No | Yes | Yes |

## Real-World Benchmark

Performance on a 10,000 document spam classification task:

| Metric | Naive Bayes | Logistic Regression | KNN (k=5) | LSI |
|--------|-------------|---------------------|-----------|-----|
| **Training time** | 0.3s | 5s | 2.5s | 4s |
| **Model file size** | 85 KB | 150 KB | 8 MB | 6 MB |
| **Accuracy** | 94.2% | 95.1% | 91.5% | 88.3% |
| **Classify 1 document** | 0.05ms | 0.05ms | 15ms | 20ms |
| **Classify 10K documents** | 0.5s | 0.5s | 150s | 200s |
| **Memory usage** | 2 MB | 3 MB | 35 MB | 30 MB |

## When to Use Each Classifier

### Naive Bayes

**Choose Naive Bayes when you need:**
- Maximum classification speed
- Streaming or incremental training
- Simple, low-resource deployment
- Quick prototyping

```ruby
# Great for: spam filters, real-time classification
classifier = Classifier::Bayes.new 'Spam', 'Ham'
classifier.train(spam: spam_emails, ham: good_emails)
classifier.classify(incoming_email)  # ~0.05ms
```

**Avoid when:** You need semantic understanding or finding similar documents.

### Logistic Regression

**Choose Logistic Regression when you need:**
- Best classification accuracy
- Well-calibrated probability scores
- Feature importance analysis
- Confidence thresholds for decisions

```ruby
# Great for: sentiment analysis, high-stakes classification
classifier = Classifier::LogisticRegression.new 'Positive', 'Negative', 'Neutral'
classifier.train(positive: good_reviews, negative: bad_reviews, neutral: meh_reviews)
classifier.probabilities(review)  # => {"Positive" => 0.82, "Negative" => 0.12, "Neutral" => 0.06}
classifier.weights(:positive, limit: 10)  # Top 10 words indicating positive
```

**Avoid when:** You have very small training sets or need incremental learning.

### KNN (k-Nearest Neighbors)

**Choose KNN when you need:**
- Classification AND similarity search
- Explainable results ("similar to these documents")
- Multi-label classification
- Incremental updates

```ruby
# Great for: recommendation systems, tag suggestions
knn = Classifier::KNN.new(k: 5, weighted: true)
knn.add(tech: tech_articles, sports: sports_articles)
result = knn.classify_with_neighbors(new_article)
# => {category: "Tech", confidence: 0.85, neighbors: [...]}
```

**Avoid when:** You have large datasets (>10K documents) or need real-time speed.

### LSI (Latent Semantic Indexing)

**Choose LSI when you need:**
- Semantic search across documents
- Finding related or similar content
- Document clustering
- Understanding word relationships

```ruby
# Great for: search engines, content discovery
lsi = Classifier::LSI.new
lsi.add(
  "Ruby" => "Ruby is a dynamic programming language",
  "Python" => "Python is great for data science"
)
lsi.search("programming languages")  # Semantic search
lsi.find_related("Ruby article")     # Find similar documents
```

**Avoid when:** You only need classification - use Bayes or LogReg instead.

## Decision Flowchart

```
                         START
                           |
          Do you need to find similar documents?
                    /              \
                  YES              NO
                   |                |
     Do you also need         Do you need
     clustering/search?       real-time speed?
          /      \               /      \
        YES      NO            YES      NO
         |        |             |        |
        LSI      KNN            |    Is accuracy
                                |    critical?
                                |      /    \
                                |    YES    NO
                                |     |      |
                          Need calibrated    |
                          probabilities?     |
                             /    \          |
                           YES    NO         |
                            |      |         |
                         LogReg  Bayes    Bayes
```

## Summary

| If you want... | Use |
|----------------|-----|
| **Just classify text, keep it simple** | Naive Bayes |
| **Best classification accuracy** | Logistic Regression |
| **Probability scores you can threshold** | Logistic Regression |
| **Find similar documents** | KNN or LSI |
| **Semantic search** | LSI |
| **Cluster documents by topic** | LSI |
| **Maximum speed** | Naive Bayes |
| **Smallest model size** | Naive Bayes |
| **Feature importance** | Logistic Regression |
| **Classification + similarity** | KNN |

## Next Steps

- [Bayes Basics](/docs/guides/bayes/basics) - Get started with Naive Bayes
- [Logistic Regression](/docs/guides/logisticregression/basics) - Learn about calibrated classification
- [KNN Basics](/docs/guides/knn/basics) - Explore instance-based classification
- [LSI Basics](/docs/guides/lsi/basics) - Dive into semantic analysis
- [Ensemble Classifier Tutorial](/docs/tutorials/ensemble-classifier) - Combine multiple classifiers for even better results
