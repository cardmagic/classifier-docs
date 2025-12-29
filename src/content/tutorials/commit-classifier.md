---
title: "Git Commit Classifier"
description: "Automatically classify git commits as feat, fix, docs, refactor, and more using Bayesian classification."
difficulty: beginner
classifiers: [bayes]
order: 3
---

# Git Commit Classifier

Build a tool that analyzes git commits and classifies them according to Conventional Commits types. Use it to auto-label commits, generate changelogs, or audit commit hygiene.

## What You'll Learn

- Training on real git commit patterns
- Multi-category classification with Bayes
- Parsing and preprocessing commit messages
- Building a practical developer tool

## Why Bayes for Commits?

- **Fast**: Classify thousands of commits instantly
- **Learns patterns**: Catches variations in commit style
- **Confidence scores**: Know when a commit is ambiguous
- **Low memory**: Stores word frequencies, not all examples

## Project Setup

```bash
mkdir commit_classifier && cd commit_classifier
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## The Commit Classifier

Create `commit_classifier.rb`:

```ruby
require 'classifier'
require 'json'

class CommitClassifier
  TYPES = %w[feat fix docs style refactor test chore build ci perf]

  def initialize
    @classifier = Classifier::Bayes.new(*TYPES.map(&:capitalize))
  end

  # Train with a commit message and its type
  def train(type, message)
    type = normalize_type(type)
    raise ArgumentError, "Invalid type: #{type}" unless TYPES.include?(type)

    clean_message = preprocess(message)
    @classifier.train(type.to_sym => clean_message)
  end

  # Train from an array of {type:, message:} hashes
  def train_batch(commits)
    commits.each { |c| train(c[:type], c[:message]) }
  end

  # Classify a commit message
  def classify(message)
    clean_message = preprocess(message)
    predicted = @classifier.classify(clean_message)

    scores = @classifier.classifications(clean_message)
    confidence = calculate_confidence(scores)

    {
      type: predicted.downcase,
      confidence: confidence,
      scores: normalize_scores(scores),
      original: message,
      suggestion: suggest_prefix(predicted.downcase, message)
    }
  end

  # Suggest Conventional Commit format
  def suggest_prefix(type, message)
    # Strip any existing prefix
    clean = message.sub(/^(feat|fix|docs|style|refactor|test|chore|build|ci|perf)(\(.+?\))?:\s*/i, '')
    "#{type}: #{clean}"
  end

  # Analyze a repo's commit history
  def analyze_repo(path, limit: 100)
    commits = `cd "#{path}" && git log --oneline -#{limit} --format="%s"`.split("\n")

    results = commits.map { |msg| classify(msg) }

    {
      commits: results,
      summary: summarize(results),
      suggestions: results.select { |r| needs_prefix?(r[:original]) }
    }
  end

  def save(path)
    @classifier.storage = Classifier::Storage::File.new(path: path)
    @classifier.save
  end

  def self.load(path)
    classifier = new
    storage = Classifier::Storage::File.new(path: path)
    classifier.instance_variable_set(:@classifier, Classifier::Bayes.load(storage: storage))
    classifier
  end

  private

  def normalize_type(type)
    type.to_s.downcase.strip
  end

  def preprocess(message)
    # Remove conventional commit prefix if present
    message = message.sub(/^(feat|fix|docs|style|refactor|test|chore|build|ci|perf)(\(.+?\))?:\s*/i, '')

    # Remove issue references
    message = message.gsub(/#\d+/, '')

    # Remove common noise
    message = message.gsub(/\[.*?\]/, '')  # [skip ci], [WIP], etc.

    message.strip
  end

  def calculate_confidence(scores)
    exp_scores = scores.transform_values { |s| Math.exp(s) }
    total = exp_scores.values.sum
    max_score = exp_scores.values.max
    ((max_score / total) * 100).round(1)
  end

  def normalize_scores(scores)
    exp_scores = scores.transform_values { |s| Math.exp(s) }
    total = exp_scores.values.sum
    exp_scores.transform_values { |s| ((s / total) * 100).round(1) }
      .sort_by { |_, v| -v }
      .first(3)
      .to_h
  end

  def summarize(results)
    by_type = results.group_by { |r| r[:type] }

    {
      total: results.length,
      by_type: by_type.transform_values(&:count).sort_by { |_, v| -v }.to_h,
      avg_confidence: (results.sum { |r| r[:confidence] } / results.length).round(1),
      needs_prefix: results.count { |r| needs_prefix?(r[:original]) }
    }
  end

  def needs_prefix?(message)
    !message.match?(/^(feat|fix|docs|style|refactor|test|chore|build|ci|perf)(\(.+?\))?:/i)
  end
end
```

## Training the Classifier

Create `train.rb`:

```ruby
require_relative 'commit_classifier'

classifier = CommitClassifier.new

# Training data based on Conventional Commits patterns
training_data = [
  # feat - new features
  { type: 'feat', message: 'add user authentication' },
  { type: 'feat', message: 'implement search functionality' },
  { type: 'feat', message: 'add dark mode support' },
  { type: 'feat', message: 'create new dashboard component' },
  { type: 'feat', message: 'implement OAuth login' },
  { type: 'feat', message: 'add file upload feature' },
  { type: 'feat', message: 'support multiple languages' },
  { type: 'feat', message: 'add notifications system' },
  { type: 'feat', message: 'implement user profiles' },
  { type: 'feat', message: 'add API endpoint for products' },

  # fix - bug fixes
  { type: 'fix', message: 'resolve login redirect issue' },
  { type: 'fix', message: 'correct calculation error in totals' },
  { type: 'fix', message: 'handle null pointer exception' },
  { type: 'fix', message: 'prevent duplicate form submissions' },
  { type: 'fix', message: 'fix memory leak in background job' },
  { type: 'fix', message: 'resolve race condition in cache' },
  { type: 'fix', message: 'correct date formatting bug' },
  { type: 'fix', message: 'handle edge case in validation' },
  { type: 'fix', message: 'patch security vulnerability' },
  { type: 'fix', message: 'fix broken image loading' },

  # docs - documentation
  { type: 'docs', message: 'update README with examples' },
  { type: 'docs', message: 'add API documentation' },
  { type: 'docs', message: 'document installation steps' },
  { type: 'docs', message: 'add contributing guidelines' },
  { type: 'docs', message: 'update changelog' },
  { type: 'docs', message: 'improve inline code comments' },
  { type: 'docs', message: 'add usage examples to docs' },
  { type: 'docs', message: 'document environment variables' },

  # style - formatting, no code change
  { type: 'style', message: 'format code with prettier' },
  { type: 'style', message: 'fix indentation issues' },
  { type: 'style', message: 'remove trailing whitespace' },
  { type: 'style', message: 'apply consistent naming convention' },
  { type: 'style', message: 'organize imports alphabetically' },
  { type: 'style', message: 'fix linting errors' },

  # refactor - restructuring code
  { type: 'refactor', message: 'extract method for reusability' },
  { type: 'refactor', message: 'simplify conditional logic' },
  { type: 'refactor', message: 'rename variables for clarity' },
  { type: 'refactor', message: 'modularize authentication code' },
  { type: 'refactor', message: 'restructure folder organization' },
  { type: 'refactor', message: 'improve code readability' },
  { type: 'refactor', message: 'consolidate duplicate functions' },
  { type: 'refactor', message: 'split large component into smaller ones' },

  # test - testing
  { type: 'test', message: 'add unit tests for user service' },
  { type: 'test', message: 'increase test coverage' },
  { type: 'test', message: 'add integration tests' },
  { type: 'test', message: 'fix flaky test in auth module' },
  { type: 'test', message: 'add e2e tests for checkout flow' },
  { type: 'test', message: 'mock external API calls in tests' },

  # chore - maintenance
  { type: 'chore', message: 'update dependencies' },
  { type: 'chore', message: 'bump version to 2.0.0' },
  { type: 'chore', message: 'clean up unused files' },
  { type: 'chore', message: 'update gitignore' },
  { type: 'chore', message: 'configure eslint rules' },
  { type: 'chore', message: 'upgrade node version' },

  # build - build system
  { type: 'build', message: 'configure webpack for production' },
  { type: 'build', message: 'add docker support' },
  { type: 'build', message: 'update build scripts' },
  { type: 'build', message: 'optimize bundle size' },
  { type: 'build', message: 'add asset compilation step' },

  # ci - continuous integration
  { type: 'ci', message: 'add GitHub Actions workflow' },
  { type: 'ci', message: 'configure automated testing' },
  { type: 'ci', message: 'setup deployment pipeline' },
  { type: 'ci', message: 'add code coverage reporting' },
  { type: 'ci', message: 'fix CI build failure' },

  # perf - performance
  { type: 'perf', message: 'optimize database queries' },
  { type: 'perf', message: 'add caching layer' },
  { type: 'perf', message: 'reduce bundle size' },
  { type: 'perf', message: 'lazy load images' },
  { type: 'perf', message: 'improve page load time' },
]

classifier.train_batch(training_data)
classifier.save('commit_classifier.json')

puts "Trained on #{training_data.length} commits"
puts "Types: #{CommitClassifier::TYPES.join(', ')}"
```

## Classifying Commits

Create `classify.rb`:

```ruby
require_relative 'commit_classifier'

classifier = CommitClassifier.load('commit_classifier.json')

# Test commits to classify
test_commits = [
  "add new payment gateway integration",
  "resolve issue with user logout",
  "update the installation guide",
  "reorganize the utils folder structure",
  "add tests for the cart component",
  "bump lodash to latest version",
  "setup CircleCI pipeline",
  "improve query performance with indexes",
  "apply prettier formatting",
  "WIP trying something new",  # Ambiguous
]

puts "=" * 70
puts "GIT COMMIT CLASSIFIER"
puts "=" * 70

test_commits.each do |message|
  result = classifier.classify(message)

  puts "\nCommit: #{message}"
  puts "Type: #{result[:type]} (#{result[:confidence]}% confidence)"
  puts "Suggested: #{result[:suggestion]}"
  puts "Top scores: #{result[:scores].map { |t, s| "#{t}:#{s}%" }.join(', ')}"
end
```

Run it:

```bash
ruby train.rb
ruby classify.rb
```

Output:
```
======================================================================
GIT COMMIT CLASSIFIER
======================================================================

Commit: add new payment gateway integration
Type: feat (24.4% confidence)
Suggested: feat: add new payment gateway integration
Top scores: Feat:24.4%, Test:22.1%, Docs:15.7%

Commit: resolve issue with user logout
Type: fix (32.7% confidence)
Suggested: fix: resolve issue with user logout
Top scores: Fix:32.7%, Feat:18.5%, Style:10.2%

Commit: update the installation guide
Type: docs (37.6% confidence)
Suggested: docs: update the installation guide
Top scores: Docs:37.6%, Chore:15.8%, Build:8.9%
```

**Note:** With 10 commit types, confidence scores are naturally lower since probability is distributed across more categories. The classifier still picks the correct type—focus on whether it's the highest-scoring category rather than absolute percentages.

## Analyze a Real Repository

Create `analyze_repo.rb`:

```ruby
require_relative 'commit_classifier'

classifier = CommitClassifier.load('commit_classifier.json')

# Analyze current repo (or specify a path)
repo_path = ARGV[0] || '.'
limit = (ARGV[1] || 50).to_i

puts "Analyzing #{limit} commits from: #{repo_path}"
puts "=" * 60

analysis = classifier.analyze_repo(repo_path, limit: limit)
summary = analysis[:summary]

puts "\n📊 COMMIT TYPE DISTRIBUTION"
puts "-" * 40
summary[:by_type].each do |type, count|
  bar = "█" * (count * 2)
  pct = ((count.to_f / summary[:total]) * 100).round(1)
  puts "#{type.ljust(10)} #{bar} #{count} (#{pct}%)"
end

puts "\n📈 STATISTICS"
puts "-" * 40
puts "Total commits analyzed: #{summary[:total]}"
puts "Average confidence: #{summary[:avg_confidence]}%"
puts "Missing conventional prefix: #{summary[:needs_prefix]}"

if analysis[:suggestions].any?
  puts "\n💡 SUGGESTED PREFIXES"
  puts "-" * 40
  analysis[:suggestions].first(10).each do |commit|
    puts "  #{commit[:original][0..50]}#{'...' if commit[:original].length > 50}"
    puts "  → #{commit[:suggestion]}"
    puts
  end
end
```

Run it:

```bash
ruby analyze_repo.rb /path/to/your/repo 100
```

## Git Hook Integration

Create a pre-commit hook that suggests types:

```ruby
#!/usr/bin/env ruby
# Save as .git/hooks/prepare-commit-msg

require_relative 'path/to/commit_classifier'

message_file = ARGV[0]
message = File.read(message_file).strip

# Skip if already has a conventional prefix
exit 0 if message.match?(/^(feat|fix|docs|style|refactor|test|chore|build|ci|perf)(\(.+?\))?:/i)

classifier = CommitClassifier.load('path/to/commit_classifier.json')
result = classifier.classify(message)

if result[:confidence] > 70
  # Auto-suggest the prefix
  suggested = result[:suggestion]
  File.write(message_file, suggested)
  puts "Auto-prefixed commit as: #{result[:type]}"
else
  puts "Suggested type: #{result[:type]} (#{result[:confidence]}% confidence)"
  puts "Consider: #{result[:suggestion]}"
end
```

## Train on Your Own Commits

```ruby
# Extract training data from a well-maintained repo
def extract_training_data(repo_path, limit: 500)
  commits = `cd "#{repo_path}" && git log --oneline -#{limit} --format="%s"`.split("\n")

  commits.filter_map do |msg|
    # Only use commits with conventional prefix
    if match = msg.match(/^(feat|fix|docs|style|refactor|test|chore|build|ci|perf)(\(.+?\))?:\s*(.+)/i)
      { type: match[1].downcase, message: match[3] }
    end
  end
end

# Train on your repo's history
training = extract_training_data('/path/to/well-formatted-repo')
puts "Found #{training.length} properly formatted commits"

classifier = CommitClassifier.new
classifier.train_batch(training)
classifier.save('custom_classifier.json')
```

## Best Practices

1. **Train on your codebase**: Every team has different commit patterns
2. **Use confidence thresholds**: Only auto-apply high-confidence classifications
3. **Regular retraining**: Periodically retrain on recent commits
4. **Handle ambiguity**: Some commits genuinely span multiple types

## Next Steps

- [Bayes Basics](/docs/guides/bayes/basics) - Deep dive into Bayesian classification
- [Persistence Guide](/docs/guides/persistence/basics) - Production storage strategies
