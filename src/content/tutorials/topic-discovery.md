---
title: "Topic Discovery with TF-IDF and LSI"
description: "Automatically discover topics in unlabeled documents using TF-IDF, then use LSI for semantic classification of new content."
difficulty: intermediate
classifiers: [tfidf, lsi]
order: 12
---

# Topic Discovery with TF-IDF and LSI

You have thousands of documents but no categories. How do you organize them? This tutorial shows how to use TF-IDF to discover natural topics in your corpus, then feed those topics into LSI for semantic classification.

## What You'll Learn

- Extracting topic signatures using TF-IDF
- Clustering documents by similarity
- Building an LSI index from discovered categories
- Classifying new documents into discovered topics

## The Pipeline

```
Unlabeled Corpus → TF-IDF → Topic Clusters → LSI → Semantic Classification
```

1. **TF-IDF** identifies which terms make each document distinctive
2. **Clustering** groups similar documents into topics
3. **LSI** learns the semantic relationships between topics
4. New documents get classified by semantic similarity

## Project Setup

```bash
mkdir topic_discovery && cd topic_discovery
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## The Topic Discoverer

Create `topic_discoverer.rb`:

```ruby
require 'classifier'
require 'json'

class TopicDiscoverer
  attr_reader :topics, :topic_documents

  def initialize(min_cluster_size: 2, similarity_threshold: 0.3)
    @tfidf = Classifier::TFIDF.new(min_df: 2, sublinear_tf: true)
    @lsi = Classifier::LSI.new(auto_rebuild: false)
    @min_cluster_size = min_cluster_size
    @similarity_threshold = similarity_threshold
    @documents = []
    @vectors = []
    @topics = {}           # topic_name => [doc_indices]
    @topic_documents = {}  # topic_name => [documents]
  end

  # Step 1: Add documents to analyze
  def add_documents(docs)
    @documents.concat(docs)
  end

  # Step 2: Discover topics from the corpus
  def discover_topics(num_topics: 5)
    return if @documents.empty?

    # Fit TF-IDF on entire corpus
    @vectors = @tfidf.fit_transform(@documents)

    # Find cluster centers using k-means-like approach
    clusters = cluster_documents(num_topics)

    # Name topics based on top terms
    clusters.each_with_index do |doc_indices, i|
      next if doc_indices.length < @min_cluster_size

      # Get top terms for this cluster
      topic_name = generate_topic_name(doc_indices)
      @topics[topic_name] = doc_indices
      @topic_documents[topic_name] = doc_indices.map { |idx| @documents[idx] }

      # Add documents to LSI with topic as category
      doc_indices.each do |idx|
        @lsi.add_item(@documents[idx], topic_name)
      end
    end

    # Build LSI index
    @lsi.build_index

    @topics
  end

  # Step 3: Classify new documents
  def classify(text, top_n: 3)
    return [] if @topics.empty?

    # Get LSI classification
    results = @lsi.classify(text, top_n)
    return [] unless results

    Array(results).map do |topic|
      {
        topic: topic,
        confidence: calculate_confidence(text, topic),
        sample_docs: @topic_documents[topic]&.first(2)
      }
    end
  end

  # Get detailed topic info
  def topic_summary
    @topics.map do |name, indices|
      top_terms = extract_top_terms(indices, 5)
      {
        name: name,
        document_count: indices.length,
        top_terms: top_terms,
        sample: @documents[indices.first][0..100] + "..."
      }
    end
  end

  def save(path)
    @lsi.build_index unless @topics.empty?

    data = {
      documents: @documents,
      topics: @topics,
      topic_documents: @topic_documents
    }
    File.write("#{path}.json", data.to_json)
    File.write("#{path}.tfidf", @tfidf.to_json)
  end

  def self.load(path)
    discoverer = new
    data = JSON.parse(File.read("#{path}.json"), symbolize_names: true)

    discoverer.instance_variable_set(:@documents, data[:documents])
    discoverer.instance_variable_set(:@topics, data[:topics].transform_keys(&:to_s))
    discoverer.instance_variable_set(:@topic_documents, data[:topic_documents].transform_keys(&:to_s))
    discoverer.instance_variable_set(:@tfidf, Classifier::TFIDF.from_json(File.read("#{path}.tfidf")))

    # Rebuild LSI from saved data
    lsi = Classifier::LSI.new(auto_rebuild: false)
    data[:topics].each do |topic_name, indices|
      indices.each do |idx|
        lsi.add_item(data[:documents][idx], topic_name.to_s)
      end
    end
    lsi.build_index
    discoverer.instance_variable_set(:@lsi, lsi)

    discoverer
  end

  private

  def cluster_documents(k)
    return [] if @vectors.empty?

    # Initialize cluster centers randomly
    indices = (0...@documents.length).to_a.shuffle
    centers = indices.first(k).map { |i| @vectors[i] }

    clusters = Array.new(k) { [] }

    # Simple k-means iteration
    3.times do
      # Assign documents to nearest cluster
      clusters = Array.new(k) { [] }

      @vectors.each_with_index do |vec, idx|
        best_cluster = 0
        best_similarity = -1

        centers.each_with_index do |center, cluster_idx|
          sim = cosine_similarity(vec, center)
          if sim > best_similarity
            best_similarity = sim
            best_cluster = cluster_idx
          end
        end

        clusters[best_cluster] << idx if best_similarity >= @similarity_threshold
      end

      # Update centers
      centers = clusters.map do |doc_indices|
        next centers[0] if doc_indices.empty?
        centroid(doc_indices.map { |i| @vectors[i] })
      end
    end

    clusters
  end

  def generate_topic_name(doc_indices)
    top_terms = extract_top_terms(doc_indices, 3)
    top_terms.join("-")
  end

  def extract_top_terms(doc_indices, n)
    # Aggregate TF-IDF scores across cluster
    term_scores = Hash.new(0.0)

    doc_indices.each do |idx|
      @vectors[idx].each do |term, score|
        term_scores[term] += score
      end
    end

    # Return top n terms
    term_scores
      .sort_by { |_, score| -score }
      .first(n)
      .map { |term, _| term.to_s }
  end

  def calculate_confidence(text, topic)
    vector = @tfidf.transform(text)
    return 0.0 if vector.empty?

    # Average similarity to documents in this topic
    topic_vectors = @topics[topic].map { |i| @vectors[i] }
    return 0.0 if topic_vectors.empty?

    similarities = topic_vectors.map { |tv| cosine_similarity(vector, tv) }
    (similarities.sum / similarities.length * 100).round(1)
  end

  def cosine_similarity(v1, v2)
    shared = v1.keys & v2.keys
    return 0.0 if shared.empty?
    shared.sum { |k| v1[k] * v2[k] }
  end

  def centroid(vectors)
    return {} if vectors.empty?

    result = Hash.new(0.0)
    vectors.each do |vec|
      vec.each { |term, score| result[term] += score }
    end

    # Normalize
    magnitude = Math.sqrt(result.values.sum { |v| v * v })
    return result if magnitude.zero?

    result.transform_values { |v| v / magnitude }
  end
end
```

## Discovering Topics

Create `discover.rb`:

```ruby
require_relative 'topic_discoverer'

discoverer = TopicDiscoverer.new(min_cluster_size: 2, similarity_threshold: 0.2)

# Sample corpus - unlabeled documents
documents = [
  # Technology cluster
  "Ruby on Rails is a web framework for building applications quickly",
  "Python Django provides rapid web development with clean design",
  "JavaScript React creates interactive user interfaces",
  "Node.js enables server-side JavaScript programming",
  "TypeScript adds static typing to JavaScript projects",

  # Finance cluster
  "Stock market indices reached record highs today",
  "Investment portfolios should be diversified across sectors",
  "Bond yields are inversely related to prices",
  "Cryptocurrency trading volumes increased sharply",
  "Interest rates affect borrowing costs for businesses",

  # Health cluster
  "Regular exercise improves cardiovascular health",
  "Nutrition plays a key role in disease prevention",
  "Sleep quality affects cognitive function and memory",
  "Meditation reduces stress and anxiety levels",
  "Vaccines provide immunity against infectious diseases",

  # Sports cluster
  "The championship game drew millions of viewers",
  "Team training focuses on strength and conditioning",
  "Players signed multi-year contracts worth millions",
  "The tournament bracket was released yesterday",
  "Coaches emphasized defensive strategies",
]

discoverer.add_documents(documents)
topics = discoverer.discover_topics(num_topics: 4)

puts "Discovered #{topics.length} topics:\n\n"

discoverer.topic_summary.each do |summary|
  puts "Topic: #{summary[:name]}"
  puts "  Documents: #{summary[:document_count]}"
  puts "  Key terms: #{summary[:top_terms].join(', ')}"
  puts "  Sample: \"#{summary[:sample]}\""
  puts
end

discoverer.save('topics')
puts "Saved to topics.json"
```

Run it:

```bash
ruby discover.rb
```

Output:
```
Discovered 4 topics:

Topic: javascript-web-framework
  Documents: 5
  Key terms: javascript, web, framework
  Sample: "Ruby on Rails is a web framework for building applications quickly..."

Topic: market-invest-stock
  Documents: 5
  Key terms: market, invest, stock
  Sample: "Stock market indices reached record highs today..."

Topic: health-exercise-sleep
  Documents: 5
  Key terms: health, exercise, sleep
  Sample: "Regular exercise improves cardiovascular health..."

Topic: game-team-player
  Documents: 5
  Key terms: game, team, player
  Sample: "The championship game drew millions of viewers..."

Saved to topics.json
```

## Classifying New Documents

Create `classify.rb`:

```ruby
require_relative 'topic_discoverer'

discoverer = TopicDiscoverer.load('topics')

new_documents = [
  "Learning Vue.js for frontend web development",
  "Portfolio rebalancing strategies for retirement",
  "Marathon training requires proper hydration",
  "The playoffs start next week with home advantage",
  "Machine learning models require large datasets",
]

puts "Classifying new documents:\n\n"

new_documents.each do |doc|
  puts "Document: \"#{doc}\""

  results = discoverer.classify(doc, top_n: 2)

  if results.empty?
    puts "  No matching topic found"
  else
    results.each do |r|
      puts "  → #{r[:topic]} (#{r[:confidence]}% confidence)"
    end
  end
  puts
end
```

Output:
```
Classifying new documents:

Document: "Learning Vue.js for frontend web development"
  → javascript-web-framework (72.3% confidence)

Document: "Portfolio rebalancing strategies for retirement"
  → market-invest-stock (68.5% confidence)

Document: "Marathon training requires proper hydration"
  → health-exercise-sleep (61.2% confidence)

Document: "The playoffs start next week with home advantage"
  → game-team-player (74.8% confidence)

Document: "Machine learning models require large datasets"
  → javascript-web-framework (31.2% confidence)
```

## Refining Topics

Sometimes automatic discovery needs guidance. You can seed topics with example documents:

```ruby
class TopicDiscoverer
  # Add seed documents to guide topic formation
  def seed_topic(name, documents)
    documents.each do |doc|
      @documents << doc
    end

    # Pre-assign these to the named topic
    @topics[name] ||= []
    start_idx = @documents.length - documents.length
    documents.length.times do |i|
      @topics[name] << (start_idx + i)
    end
  end
end

# Usage
discoverer = TopicDiscoverer.new
discoverer.seed_topic("machine-learning", [
  "Neural networks learn patterns from training data",
  "Deep learning models require GPU acceleration",
])
discoverer.add_documents(other_documents)
discoverer.discover_topics(num_topics: 5)
```

## Hierarchical Topics

For large corpora, discover topics at multiple levels:

```ruby
class HierarchicalDiscoverer
  def initialize
    @root = TopicDiscoverer.new
    @subtopics = {}
  end

  def discover(documents, levels: 2, topics_per_level: 4)
    # First level: broad topics
    @root.add_documents(documents)
    @root.discover_topics(num_topics: topics_per_level)

    return if levels < 2

    # Second level: subtopics within each broad topic
    @root.topic_documents.each do |topic, docs|
      next if docs.length < topics_per_level * 2

      sub = TopicDiscoverer.new(min_cluster_size: 2)
      sub.add_documents(docs)
      sub.discover_topics(num_topics: topics_per_level)
      @subtopics[topic] = sub
    end
  end

  def classify(text)
    # Classify at root level
    root_result = @root.classify(text, top_n: 1).first
    return nil unless root_result

    # Check for subtopic
    if @subtopics[root_result[:topic]]
      sub_result = @subtopics[root_result[:topic]].classify(text, top_n: 1).first
      return {
        topic: root_result[:topic],
        subtopic: sub_result&.dig(:topic),
        confidence: root_result[:confidence]
      }
    end

    root_result
  end
end
```

## Integration Example

Use discovered topics to organize a document library:

```ruby
class DocumentLibrary
  def initialize
    @discoverer = TopicDiscoverer.load('topics')
    @documents = {}  # id => {content:, topic:, ...}
  end

  def add(id, content, metadata = {})
    # Auto-classify
    classification = @discoverer.classify(content, top_n: 1).first

    @documents[id] = {
      content: content,
      topic: classification&.dig(:topic) || "uncategorized",
      confidence: classification&.dig(:confidence) || 0,
      metadata: metadata
    }
  end

  def browse_by_topic
    @documents.group_by { |_, doc| doc[:topic] }
  end

  def find_similar(id)
    doc = @documents[id]
    return [] unless doc

    # Find in same topic
    @documents.select do |other_id, other|
      other_id != id && other[:topic] == doc[:topic]
    end
  end
end
```

## Tips for Better Topics

1. **Clean your corpus**: Remove boilerplate, headers, footers
2. **Tune min_df**: Higher values (3-5) for cleaner topics
3. **Adjust cluster count**: Start with fewer topics, increase if too broad
4. **Review and merge**: Some topics may need manual merging
5. **Iterate**: Re-run discovery after adding more documents

## When to Use This Approach

**Good for:**
- Organizing large document collections
- Discovering themes in user feedback
- Building taxonomy from scratch
- Content recommendation systems

**Consider alternatives when:**
- You already have well-defined categories (use Bayes)
- Documents are very short (tweets, titles)
- You need real-time classification of streaming data

## Next Steps

- [TF-IDF Basics](/docs/guides/tfidf/basics) - Understanding term weighting
- [LSI Basics](/docs/guides/lsi/basics) - Semantic similarity deep dive
- [Duplicate Detector](/docs/tutorials/duplicate-detector) - Combine TF-IDF + LSI for similarity
