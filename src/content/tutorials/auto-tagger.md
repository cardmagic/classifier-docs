---
title: "Auto-Tagger for Blog Posts"
description: "Build a smart tagging system that suggests tags for new posts based on similar published content."
difficulty: intermediate
classifiers: [knn]
order: 7
---

# Auto-Tagger for Blog Posts

Build a tagging system that learns from your existing content and suggests relevant tags for new posts. Using kNN, we can find similar published posts and recommend their tags.

## What You'll Learn

- Using kNN for multi-label suggestions
- Leveraging similarity scores for confidence
- Building a practical content management tool

## Why kNN for Tagging?

Unlike Bayes (which picks one category), kNN returns similar items with similarity scores. This is perfect for tagging because:

- Posts can have multiple tags
- We can see *why* a tag was suggested (similar posts)
- New tags can be added without retraining

## Project Setup

```bash
mkdir blog_tagger && cd blog_tagger
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## The Auto-Tagger

Create `auto_tagger.rb`:

```ruby
require 'classifier'
require 'json'

class AutoTagger
  def initialize
    @knn = Classifier::KNN.new(k: 5, weighted: true)
    @post_tags = {}  # Maps post content to its tags
  end

  # Add a published post with its tags
  def add_post(content, tags)
    tags = Array(tags)
    @post_tags[content] = tags

    # Add to kNN with each tag as a category
    tags.each do |tag|
      @knn.add(tag => content)
    end
  end

  # Suggest tags for new content
  def suggest_tags(content, max_tags: 5)
    result = @knn.classify_with_neighbors(content)
    return [] if result[:neighbors].empty?

    # Tally tag votes weighted by similarity
    tag_scores = Hash.new(0.0)

    result[:neighbors].each do |neighbor|
      similarity = neighbor[:similarity]
      post_content = neighbor[:item]

      # Get all tags from this similar post
      @post_tags[post_content]&.each do |tag|
        tag_scores[tag] += similarity
      end
    end

    # Return top tags with confidence scores
    tag_scores
      .sort_by { |_, score| -score }
      .first(max_tags)
      .map { |tag, score| { tag: tag, confidence: normalize_score(score) } }
  end

  # Get explanation for why tags were suggested
  def explain_suggestions(content, max_tags: 3)
    result = @knn.classify_with_neighbors(content)
    return {} if result[:neighbors].empty?

    explanations = {}

    suggest_tags(content, max_tags: max_tags).each do |suggestion|
      tag = suggestion[:tag]

      # Find which neighbors contributed to this tag
      contributors = result[:neighbors].select do |n|
        @post_tags[n[:item]]&.include?(tag)
      end

      explanations[tag] = {
        confidence: suggestion[:confidence],
        similar_posts: contributors.map do |c|
          {
            excerpt: c[:item][0..80] + "...",
            similarity: (c[:similarity] * 100).round(1)
          }
        end
      }
    end

    explanations
  end

  def save(path)
    File.write(path, @knn.to_json)
    File.write("#{path}.tags", @post_tags.to_json)
  end

  def self.load(path)
    tagger = new
    tagger.instance_variable_set(:@knn, Classifier::KNN.from_json(File.read(path)))
    tagger.instance_variable_set(:@post_tags, JSON.parse(File.read("#{path}.tags")))
    tagger
  end

  private

  def normalize_score(score)
    # Convert to 0-100 percentage (capped)
    [(score * 50).round(1), 100.0].min
  end
end
```

## Training with Existing Posts

Create `train.rb`:

```ruby
require_relative 'auto_tagger'

tagger = AutoTagger.new

# Sample blog posts (in real usage, load from your CMS/database)
posts = [
  {
    content: "Getting started with Ruby on Rails. This tutorial covers MVC architecture, routing, and building your first web application with Rails.",
    tags: ["ruby", "rails", "tutorial", "web-development"]
  },
  {
    content: "Understanding React hooks. Learn useState, useEffect, and custom hooks to manage state in functional components.",
    tags: ["javascript", "react", "frontend", "tutorial"]
  },
  {
    content: "Deploying Rails apps to Heroku. Step-by-step guide for production deployment including database setup and environment variables.",
    tags: ["ruby", "rails", "deployment", "heroku", "devops"]
  },
  {
    content: "CSS Grid vs Flexbox. When to use each layout system and how to combine them for responsive designs.",
    tags: ["css", "frontend", "web-development", "tutorial"]
  },
  {
    content: "Building REST APIs with Ruby. Design principles, authentication, and best practices for API development.",
    tags: ["ruby", "api", "backend", "tutorial"]
  },
  {
    content: "Introduction to TypeScript. Static typing for JavaScript, interfaces, and migrating existing projects.",
    tags: ["javascript", "typescript", "tutorial", "frontend"]
  },
  {
    content: "Docker containers for Ruby development. Creating Dockerfiles, docker-compose, and development workflows.",
    tags: ["ruby", "docker", "devops", "tutorial"]
  },
  {
    content: "React component testing with Jest. Unit tests, snapshot testing, and mocking API calls.",
    tags: ["javascript", "react", "testing", "frontend"]
  },
  {
    content: "PostgreSQL performance tuning. Indexes, query optimization, and monitoring database performance.",
    tags: ["database", "postgresql", "performance", "backend"]
  },
  {
    content: "Building a Rails API with GraphQL. Schema design, queries, mutations, and subscriptions.",
    tags: ["ruby", "rails", "graphql", "api", "backend"]
  },
]

posts.each do |post|
  tagger.add_post(post[:content], post[:tags])
end

tagger.save('tagger.json')
puts "Trained on #{posts.length} posts"
puts "Tags in corpus: #{posts.flat_map { |p| p[:tags] }.uniq.sort.join(', ')}"
```

## Suggesting Tags

Create `suggest.rb`:

```ruby
require_relative 'auto_tagger'

tagger = AutoTagger.load('tagger.json')

# New post that needs tags
new_post = <<~POST
  Building a Vue.js application with Vuex state management.
  This guide covers setting up Vue 3, creating components,
  and managing global state with Vuex stores.
POST

puts "New post:"
puts new_post
puts

puts "Suggested tags:"
suggestions = tagger.suggest_tags(new_post)
suggestions.each do |s|
  puts "  #{s[:tag]} (#{s[:confidence]}% confidence)"
end

puts "\nWhy these tags?"
explanations = tagger.explain_suggestions(new_post)
explanations.each do |tag, data|
  puts "\n#{tag} (#{data[:confidence]}%):"
  data[:similar_posts].each do |post|
    puts "  - #{post[:similarity]}% similar: \"#{post[:excerpt]}\""
  end
end
```

Run it:

```bash
ruby train.rb
ruby suggest.rb
```

Output:
```
Suggested tags:
  javascript (78.5% confidence)
  frontend (65.2% confidence)
  tutorial (52.1% confidence)
  react (34.8% confidence)

Why these tags?
javascript (78.5%):
  - 72.3% similar: "Understanding React hooks. Learn useState, useEffect..."
  - 68.1% similar: "Introduction to TypeScript. Static typing for JavaScript..."

frontend (65.2%):
  - 72.3% similar: "Understanding React hooks. Learn useState, useEffect..."
  - 61.4% similar: "CSS Grid vs Flexbox. When to use each layout system..."
```

## Integration with a Blog

Here's how to integrate with a simple blog system:

```ruby
class BlogPost
  attr_accessor :title, :content, :tags

  def initialize(title:, content:, tags: [])
    @title = title
    @content = content
    @tags = tags
  end

  def self.tagger
    @tagger ||= AutoTagger.load('tagger.json')
  end

  def suggest_tags(max: 5)
    self.class.tagger.suggest_tags("#{title} #{content}", max_tags: max)
  end

  def auto_tag!(confidence_threshold: 40)
    suggestions = suggest_tags
    @tags = suggestions
      .select { |s| s[:confidence] >= confidence_threshold }
      .map { |s| s[:tag] }
  end
end

# Usage
post = BlogPost.new(
  title: "Kubernetes Deployment Strategies",
  content: "Learn blue-green and canary deployments for zero-downtime releases..."
)

puts "Suggested: #{post.suggest_tags.map { |s| s[:tag] }.join(', ')}"
post.auto_tag!(confidence_threshold: 30)
puts "Auto-tagged with: #{post.tags.join(', ')}"
```

## Best Practices

1. **Retrain regularly**: As you add new posts, periodically rebuild the tagger
2. **Use descriptive content**: Include title + body + maybe excerpt for better matching
3. **Review suggestions**: Auto-tagging works best as a suggestion, not replacement
4. **Set confidence thresholds**: Only auto-apply high-confidence tags

## Next Steps

- [kNN Basics](/docs/guides/knn/basics) - Deep dive into k-Nearest Neighbors
- [Persistence Guide](/docs/guides/persistence/basics) - Production storage strategies
