---
title: "Keyword Extractor"
description: "Build a keyword extraction tool that identifies the most important terms in documents using TF-IDF weighting."
difficulty: beginner
classifiers: [tfidf]
order: 5
---

# Keyword Extractor

Build a tool that automatically extracts the most important keywords from documents. TF-IDF identifies terms that are distinctive to each document—perfect for SEO, content tagging, and document summarization.

## What You'll Learn

- Using TF-IDF for keyword extraction
- Comparing documents by their key terms
- Building a practical content analysis tool

## Why TF-IDF for Keywords?

TF-IDF naturally surfaces important terms:
- **High TF-IDF**: Words that appear often in this document but rarely in others
- **Low TF-IDF**: Common words that appear everywhere (filtered out)

This means "machine learning" in a tech article gets a high score, while "the" and "is" get near zero.

## Project Setup

```bash
mkdir keyword_extractor && cd keyword_extractor
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## The Keyword Extractor

Create `keyword_extractor.rb`:

```ruby
require 'classifier'
require 'json'

class KeywordExtractor
  def initialize(corpus = [])
    @tfidf = Classifier::TFIDF.new(
      min_df: 1,
      max_df: 0.85,       # Ignore terms in >85% of docs
      sublinear_tf: true  # Dampen high-frequency terms
    )
    @corpus = corpus
    @fitted = false
  end

  # Learn vocabulary from a corpus
  def fit(documents)
    @corpus = documents
    @tfidf.fit(documents)
    @fitted = true
    self
  end

  # Add documents to corpus and refit
  def add_documents(documents)
    @corpus += Array(documents)
    @tfidf.fit(@corpus)
    self
  end

  # Extract top keywords from a document
  def extract(document, top_n: 10)
    ensure_fitted!

    vector = @tfidf.transform(document)
    return [] if vector.empty?

    vector
      .sort_by { |_, score| -score }
      .first(top_n)
      .map { |term, score| { term: term, score: score.round(4) } }
  end

  # Extract keywords with context (surrounding text)
  def extract_with_context(document, top_n: 10)
    keywords = extract(document, top_n: top_n)

    keywords.map do |kw|
      term = kw[:term].to_s
      # Find the term in the original document
      context = find_context(document, term)
      kw.merge(context: context)
    end
  end

  # Compare two documents by their keywords
  def compare(doc1, doc2, top_n: 10)
    kw1 = extract(doc1, top_n: top_n).map { |k| k[:term] }
    kw2 = extract(doc2, top_n: top_n).map { |k| k[:term] }

    shared = kw1 & kw2
    unique_to_first = kw1 - kw2
    unique_to_second = kw2 - kw1

    {
      shared: shared,
      unique_to_first: unique_to_first,
      unique_to_second: unique_to_second,
      similarity: shared.length.to_f / (kw1 | kw2).length
    }
  end

  # Generate a keyword cloud (term => weight)
  def keyword_cloud(document, top_n: 20)
    keywords = extract(document, top_n: top_n)
    return {} if keywords.empty?

    # Normalize scores to 1-10 scale for cloud sizing
    max_score = keywords.first[:score]
    min_score = keywords.last[:score]
    range = max_score - min_score

    keywords.to_h do |kw|
      weight = range.zero? ? 5 : ((kw[:score] - min_score) / range * 9 + 1).round
      [kw[:term], weight]
    end
  end

  # Find documents similar to a query based on keyword overlap
  def find_similar(query, top_n: 5)
    ensure_fitted!

    query_vector = @tfidf.transform(query)
    return [] if query_vector.empty?

    similarities = @corpus.map.with_index do |doc, idx|
      doc_vector = @tfidf.transform(doc)
      sim = cosine_similarity(query_vector, doc_vector)
      { index: idx, document: doc[0..100], similarity: sim.round(4) }
    end

    similarities
      .sort_by { |s| -s[:similarity] }
      .reject { |s| s[:similarity] < 0.1 }
      .first(top_n)
  end

  def vocabulary_size
    @tfidf.vocabulary.size
  end

  def save(path)
    File.write(path, @tfidf.to_json)
    File.write("#{path}.corpus", @corpus.to_json)
  end

  def self.load(path)
    extractor = new
    extractor.instance_variable_set(:@tfidf, Classifier::TFIDF.from_json(File.read(path)))
    extractor.instance_variable_set(:@corpus, JSON.parse(File.read("#{path}.corpus")))
    extractor.instance_variable_set(:@fitted, true)
    extractor
  end

  private

  def ensure_fitted!
    raise "Must call fit() with a corpus first" unless @fitted
  end

  def find_context(document, term)
    # Find a sentence or phrase containing the term
    sentences = document.split(/[.!?]+/)
    match = sentences.find { |s| s.downcase.include?(term.downcase) }
    match&.strip&.slice(0, 100)
  end

  def cosine_similarity(vec1, vec2)
    shared = vec1.keys & vec2.keys
    return 0.0 if shared.empty?

    shared.sum { |k| vec1[k] * vec2[k] }
  end
end
```

## Building a Corpus

Create `train.rb`:

```ruby
require_relative 'keyword_extractor'

# Sample corpus - in production, load from your database
corpus = [
  "Ruby is a dynamic programming language focused on simplicity and productivity. It has an elegant syntax that is natural to read and easy to write.",

  "Python is a high-level programming language known for its clear syntax and readability. It's widely used in data science, machine learning, and web development.",

  "JavaScript is the language of the web, running in browsers and on servers via Node.js. Modern frameworks like React and Vue have made it even more popular.",

  "Machine learning algorithms learn from data to make predictions. Deep learning uses neural networks with many layers to learn complex patterns.",

  "Web development involves creating websites and web applications. Frontend focuses on user interface while backend handles server logic and databases.",

  "Database management systems store and retrieve data efficiently. SQL databases use structured query language while NoSQL databases offer flexible schemas.",

  "Cloud computing provides on-demand computing resources over the internet. AWS, Google Cloud, and Azure are the major cloud providers.",

  "DevOps practices combine development and operations to improve deployment speed and reliability. CI/CD pipelines automate testing and deployment.",

  "Agile methodology emphasizes iterative development and collaboration. Scrum and Kanban are popular frameworks for managing agile projects.",

  "API design focuses on creating clear, consistent interfaces for software components. REST and GraphQL are common approaches for web APIs.",
]

extractor = KeywordExtractor.new
extractor.fit(corpus)
extractor.save('extractor.json')

puts "Trained on #{corpus.length} documents"
puts "Vocabulary size: #{extractor.vocabulary_size} terms"
```

## Extracting Keywords

Create `extract.rb`:

```ruby
require_relative 'keyword_extractor'

extractor = KeywordExtractor.load('extractor.json')

# Test document
document = <<~DOC
  Building machine learning models with Python has become increasingly popular.
  Libraries like TensorFlow and PyTorch make it easy to create neural networks
  for deep learning applications. Data scientists use these tools for everything
  from image recognition to natural language processing.
DOC

puts "=" * 60
puts "KEYWORD EXTRACTION"
puts "=" * 60
puts "\nDocument:"
puts document
puts

# Extract keywords
puts "Top Keywords:"
puts "-" * 40
keywords = extractor.extract(document, top_n: 10)
keywords.each.with_index(1) do |kw, i|
  puts "#{i.to_s.rjust(2)}. #{kw[:term].to_s.ljust(20)} (score: #{kw[:score]})"
end

# Keywords with context
puts "\nKeywords in Context:"
puts "-" * 40
extractor.extract_with_context(document, top_n: 5).each do |kw|
  puts "#{kw[:term]}: \"...#{kw[:context]}...\""
  puts
end

# Keyword cloud
puts "Keyword Cloud (term => size 1-10):"
puts "-" * 40
cloud = extractor.keyword_cloud(document)
cloud.each { |term, size| puts "  #{'█' * size} #{term}" }
```

Run it:

```bash
ruby train.rb
ruby extract.rb
```

Output:
```
============================================================
KEYWORD EXTRACTION
============================================================

Document:
Building machine learning models with Python has become...

Top Keywords:
----------------------------------------
 1. learn                (score: 0.3842)
 2. machin               (score: 0.3842)
 3. python               (score: 0.3156)
 4. neural               (score: 0.2891)
 5. deep                 (score: 0.2891)
 6. data                 (score: 0.2234)
 7. network              (score: 0.2156)
 8. librari              (score: 0.1987)
 9. model                (score: 0.1876)
10. process              (score: 0.1654)

Keyword Cloud (term => size 1-10):
----------------------------------------
  ██████████ learn
  ██████████ machin
  ████████ python
  ███████ neural
  ███████ deep
```

## Comparing Documents

Create `compare.rb`:

```ruby
require_relative 'keyword_extractor'

extractor = KeywordExtractor.load('extractor.json')

doc1 = "Ruby on Rails is a web framework that makes it easy to build database-backed web applications following the MVC pattern."

doc2 = "Django is a Python web framework that encourages rapid development. It follows the model-template-view architectural pattern."

doc3 = "Machine learning models can predict outcomes based on historical data. Training requires large datasets and significant computing power."

puts "=" * 60
puts "DOCUMENT COMPARISON"
puts "=" * 60

puts "\nDocument 1: #{doc1[0..60]}..."
puts "Document 2: #{doc2[0..60]}..."
puts

comparison = extractor.compare(doc1, doc2)

puts "Comparison Results:"
puts "-" * 40
puts "Shared keywords: #{comparison[:shared].join(', ')}"
puts "Unique to Doc 1: #{comparison[:unique_to_first].join(', ')}"
puts "Unique to Doc 2: #{comparison[:unique_to_second].join(', ')}"
puts "Similarity: #{(comparison[:similarity] * 100).round(1)}%"

puts "\n" + "=" * 60
puts "\nComparing Doc 1 vs Doc 3 (very different topics):"
comparison2 = extractor.compare(doc1, doc3)
puts "Shared keywords: #{comparison2[:shared].join(', ').then { |s| s.empty? ? '(none)' : s }}"
puts "Similarity: #{(comparison2[:similarity] * 100).round(1)}%"
```

## SEO Keyword Analyzer

```ruby
class SEOAnalyzer
  def initialize(extractor)
    @extractor = extractor
  end

  def analyze(content, target_keywords: [])
    extracted = @extractor.extract(content, top_n: 20)
    extracted_terms = extracted.map { |k| k[:term].to_s }

    {
      top_keywords: extracted.first(10),
      target_keyword_coverage: check_coverage(extracted_terms, target_keywords),
      keyword_density: calculate_density(content, extracted_terms),
      suggestions: generate_suggestions(extracted_terms, target_keywords)
    }
  end

  private

  def check_coverage(extracted, targets)
    targets.map do |target|
      stem = target.downcase.stem
      found = extracted.any? { |e| e.to_s.include?(stem) || stem.include?(e.to_s) }
      { keyword: target, found: found }
    end
  end

  def calculate_density(content, keywords)
    words = content.downcase.split(/\W+/)
    total = words.length

    keywords.first(5).to_h do |kw|
      count = words.count { |w| w.stem == kw.to_s }
      [kw, (count.to_f / total * 100).round(2)]
    end
  end

  def generate_suggestions(extracted, targets)
    missing = targets.reject do |t|
      extracted.any? { |e| e.to_s.include?(t.downcase.stem) }
    end

    missing.map { |m| "Consider adding more content about '#{m}'" }
  end
end

# Usage
analyzer = SEOAnalyzer.new(extractor)
result = analyzer.analyze(
  article_content,
  target_keywords: ["ruby", "web development", "rails", "tutorial"]
)

puts "Target keyword coverage:"
result[:target_keyword_coverage].each do |kw|
  status = kw[:found] ? "✓" : "✗"
  puts "  #{status} #{kw[:keyword]}"
end
```

## Integration Example

```ruby
# In a Rails app
class Article < ApplicationRecord
  after_save :extract_keywords

  def self.extractor
    @extractor ||= KeywordExtractor.load('extractor.json')
  end

  def extract_keywords
    keywords = self.class.extractor.extract("#{title} #{body}", top_n: 10)
    update_column(:keywords, keywords.map { |k| k[:term] })
  end

  def similar_articles(limit: 5)
    results = self.class.extractor.find_similar("#{title} #{body}", top_n: limit + 1)
    # Exclude self and map to articles
    results.reject { |r| r[:index] == id }.first(limit)
  end
end
```

## N-gram Keywords

Extract multi-word phrases:

```ruby
# Enable bigrams for phrase extraction
extractor = KeywordExtractor.new
extractor.instance_variable_get(:@tfidf).instance_variable_set(
  :@ngram_range, [1, 2]
)

# Now extracts phrases like:
# - machine_learn (machine learning)
# - deep_learn (deep learning)
# - neural_network
```

## Best Practices

1. **Build domain-specific corpus**: Keywords are relative to your corpus
2. **Tune min_df/max_df**: Filter out rare typos and overly common terms
3. **Use sublinear_tf**: Prevents a word appearing 10x from dominating
4. **Consider n-grams**: Bigrams capture phrases like "machine learning"

## Next Steps

- [TF-IDF Guide](/docs/guides/tfidf/basics) - Deep dive into TF-IDF
- [LSI Basics](/docs/guides/lsi/basics) - Semantic analysis for related content
- [Duplicate Detector Tutorial](/docs/tutorials/duplicate-detector) - Combine TF-IDF with LSI
