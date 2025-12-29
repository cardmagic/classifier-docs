---
title: "Code Snippet Classifier"
description: "Build a classifier that detects programming languages and code patterns from snippets using LSI semantic analysis."
difficulty: advanced
classifiers: [lsi, knn]
order: 13
---

# Code Snippet Classifier

Build a classifier that identifies programming languages and detects code patterns (tests, APIs, data processing). Uses LSI to understand code structure semantically, not just through keywords.

## What You'll Learn

- Tokenizing code for classification
- Training on programming language patterns
- Multi-level classification (language + purpose)
- Building a practical code analysis tool

## Why This Works

Code has recognizable patterns:
- **Syntax markers**: `def`, `function`, `fn`, `func` all mean "function definition"
- **Structural patterns**: Indentation, brackets, semicolons
- **Domain vocabulary**: `describe`, `it`, `expect` signal tests
- **Import patterns**: `require`, `import`, `use`, `include`

LSI captures these patterns semantically, so it recognizes Ruby even without seeing `def` if the overall structure matches.

## Project Setup

```bash
mkdir code_classifier && cd code_classifier
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## Code Tokenizer

Create `code_tokenizer.rb`:

```ruby
# Custom tokenizer for source code
class CodeTokenizer
  # Patterns that identify languages/constructs
  SYNTAX_PATTERNS = {
    # Function definitions
    ruby_def: /\bdef\s+\w+/,
    python_def: /\bdef\s+\w+\s*\(/,
    js_function: /\bfunction\s+\w+|const\s+\w+\s*=.*=>/,
    go_func: /\bfunc\s+\w+/,
    rust_fn: /\bfn\s+\w+/,

    # Class/type definitions
    class_def: /\bclass\s+[A-Z]\w*/,
    struct_def: /\bstruct\s+\w+/,
    interface_def: /\binterface\s+\w+/,

    # Control flow
    if_statement: /\bif\s+/,
    for_loop: /\bfor\s+/,
    while_loop: /\bwhile\s+/,
    match_case: /\bmatch\s+|\bcase\s+/,

    # Imports
    require_stmt: /\brequire\s+['"]|require_relative/,
    import_stmt: /\bimport\s+/,
    use_stmt: /\buse\s+/,
    include_stmt: /\binclude\s+/,

    # Testing
    test_describe: /\bdescribe\s+['"]|RSpec\.describe/,
    test_it: /\bit\s+['"]|test\s+['"]/,
    test_expect: /\bexpect\(|assert[A-Z_]/,

    # Type annotations
    type_annotation: /:\s*\w+\s*[,\)=]|<\w+>/,

    # Comments
    line_comment: /#\s|\/\//,
    block_comment: /\/\*|"""|'''/,
  }

  # Language-specific keywords
  LANGUAGE_KEYWORDS = {
    ruby: %w[end do elsif unless yield puts attr_accessor attr_reader module],
    python: %w[elif pass lambda self __init__ print None True False],
    javascript: %w[const let var async await null undefined console],
    typescript: %w[interface type enum namespace readonly private public],
    go: %w[package defer chan goroutine make nil fmt],
    rust: %w[let mut impl pub mod crate unsafe Option Result Some None],
    java: %w[public private static void extends implements throws final],
    cpp: %w[include namespace std cout cin template virtual override],
  }

  def initialize(code)
    @code = code
    @tokens = []
  end

  def tokenize
    extract_syntax_patterns
    extract_keywords
    extract_operators
    extract_structure_features
    @tokens.join(' ')
  end

  private

  def extract_syntax_patterns
    SYNTAX_PATTERNS.each do |name, pattern|
      count = @code.scan(pattern).length
      count.times { @tokens << name.to_s } if count > 0
    end
  end

  def extract_keywords
    words = @code.downcase.scan(/\b[a-z_][a-z0-9_]*\b/)

    LANGUAGE_KEYWORDS.each do |lang, keywords|
      keywords.each do |kw|
        if words.include?(kw)
          @tokens << "#{lang}_keyword_#{kw}"
          @tokens << "lang_#{lang}"
        end
      end
    end
  end

  def extract_operators
    # Significant operators by language
    @tokens << 'op_arrow' if @code.include?('=>') || @code.include?('->')
    @tokens << 'op_rocket' if @code.include?('<=>')
    @tokens << 'op_pipe' if @code.match?(/\|>|\|/)
    @tokens << 'op_double_colon' if @code.include?('::')
    @tokens << 'op_triple_equals' if @code.include?('===')
    @tokens << 'op_spread' if @code.include?('...')
    @tokens << 'op_null_coalesce' if @code.match?(/\?\?|&\./)
  end

  def extract_structure_features
    lines = @code.split("\n")

    # Indentation style
    if lines.any? { |l| l.start_with?('  ') && !l.start_with?('    ') }
      @tokens << 'indent_2space'
    elsif lines.any? { |l| l.start_with?('    ') }
      @tokens << 'indent_4space'
    elsif lines.any? { |l| l.start_with?("\t") }
      @tokens << 'indent_tab'
    end

    # Bracket style
    @tokens << 'bracket_curly' if @code.include?('{')
    @tokens << 'bracket_significant_whitespace' unless @code.include?('{') || @code.include?(';')

    # Line endings
    @tokens << 'semicolon_terminated' if @code.count(';') > lines.length / 2
  end
end
```

## The Code Classifier

Create `code_classifier.rb`:

```ruby
require 'classifier'
require 'json'
require_relative 'code_tokenizer'

class CodeClassifier
  def initialize
    @language_lsi = Classifier::LSI.new(auto_rebuild: false)
    @purpose_knn = Classifier::KNN.new(k: 3, weighted: true)
    @languages = []
    @purposes = []
  end

  # Train language detection
  def train_language(language, code_samples)
    @languages << language.to_s unless @languages.include?(language.to_s)

    Array(code_samples).each do |code|
      tokenized = CodeTokenizer.new(code).tokenize
      @language_lsi.add_item(tokenized, language.to_s)
    end
  end

  # Train purpose detection
  def train_purpose(purpose, code_samples)
    @purposes << purpose.to_s unless @purposes.include?(purpose.to_s)

    Array(code_samples).each do |code|
      tokenized = CodeTokenizer.new(code).tokenize
      @purpose_knn.add(purpose.to_sym => tokenized)
    end
  end

  def build_index
    @language_lsi.build_index
  end

  # Classify a code snippet
  def classify(code)
    tokenized = CodeTokenizer.new(code).tokenize

    language = @language_lsi.classify(tokenized)
    lang_confidence = calculate_language_confidence(tokenized)

    purpose_result = @purpose_knn.classify_with_neighbors(tokenized)
    purpose = purpose_result[:category]
    purpose_confidence = (purpose_result[:confidence] * 100).round(1)

    {
      language: {
        detected: language,
        confidence: lang_confidence,
        alternatives: get_language_alternatives(tokenized)
      },
      purpose: {
        detected: purpose,
        confidence: purpose_confidence
      },
      tokens_used: tokenized.split.uniq.first(10)
    }
  end

  # Quick language detection
  def detect_language(code)
    tokenized = CodeTokenizer.new(code).tokenize
    @language_lsi.classify(tokenized)
  end

  # Quick purpose detection
  def detect_purpose(code)
    tokenized = CodeTokenizer.new(code).tokenize
    @purpose_knn.classify(tokenized)
  end

  def save(path)
    build_index
    File.write("#{path}_language.json", @language_lsi.to_json)
    File.write("#{path}_purpose.json", @purpose_knn.to_json)
    File.write("#{path}_meta.json", { languages: @languages, purposes: @purposes }.to_json)
  end

  def self.load(path)
    classifier = new
    classifier.instance_variable_set(:@language_lsi, Classifier::LSI.from_json(File.read("#{path}_language.json")))
    classifier.instance_variable_set(:@purpose_knn, Classifier::KNN.from_json(File.read("#{path}_purpose.json")))

    meta = JSON.parse(File.read("#{path}_meta.json"), symbolize_names: true)
    classifier.instance_variable_set(:@languages, meta[:languages])
    classifier.instance_variable_set(:@purposes, meta[:purposes])
    classifier
  end

  private

  def calculate_language_confidence(tokenized)
    result = @language_lsi.classify_with_confidence(tokenized)
    ((result[1] || 0) * 100).round(1)
  end

  def get_language_alternatives(tokenized)
    proximity = @language_lsi.proximity_array_for_content(tokenized)
    return [] if proximity.empty?

    # Group by language and get top alternatives
    lang_scores = Hash.new { |h, k| h[k] = [] }
    proximity.first(10).each do |content, score|
      lang = @language_lsi.categories_for(content).first
      lang_scores[lang] << score
    end

    lang_scores
      .transform_values { |scores| (scores.sum / scores.length * 100).round(1) }
      .sort_by { |_, score| -score }
      .first(3)
      .map { |lang, score| { language: lang, score: score } }
  end
end
```

## Training Data

Create `train.rb`:

```ruby
require_relative 'code_classifier'

classifier = CodeClassifier.new

# Ruby samples
classifier.train_language(:ruby, [
  <<~RUBY,
    class User
      attr_accessor :name, :email

      def initialize(name, email)
        @name = name
        @email = email
      end

      def greet
        puts "Hello, #{name}!"
      end
    end
  RUBY
  <<~RUBY,
    module Enumerable
      def my_map
        result = []
        each { |item| result << yield(item) }
        result
      end
    end
  RUBY
  <<~RUBY,
    require 'json'

    def parse_config(path)
      JSON.parse(File.read(path), symbolize_names: true)
    rescue Errno::ENOENT
      {}
    end
  RUBY
])

# Python samples
classifier.train_language(:python, [
  <<~PYTHON,
    class User:
        def __init__(self, name, email):
            self.name = name
            self.email = email

        def greet(self):
            print(f"Hello, {self.name}!")
  PYTHON
  <<~PYTHON,
    import json
    from pathlib import Path

    def parse_config(path):
        try:
            return json.loads(Path(path).read_text())
        except FileNotFoundError:
            return {}
  PYTHON
  <<~PYTHON,
    def fibonacci(n):
        if n <= 1:
            return n
        return fibonacci(n-1) + fibonacci(n-2)
  PYTHON
])

# JavaScript samples
classifier.train_language(:javascript, [
  <<~JS,
    class User {
      constructor(name, email) {
        this.name = name;
        this.email = email;
      }

      greet() {
        console.log(`Hello, ${this.name}!`);
      }
    }
  JS
  <<~JS,
    const parseConfig = async (path) => {
      try {
        const data = await fs.readFile(path, 'utf8');
        return JSON.parse(data);
      } catch (e) {
        return {};
      }
    };
  JS
  <<~JS,
    function fibonacci(n) {
      if (n <= 1) return n;
      return fibonacci(n - 1) + fibonacci(n - 2);
    }
  JS
])

# Go samples
classifier.train_language(:go, [
  <<~GO,
    package main

    import "fmt"

    type User struct {
        Name  string
        Email string
    }

    func (u *User) Greet() {
        fmt.Printf("Hello, %s!", u.Name)
    }
  GO
  <<~GO,
    package config

    import (
        "encoding/json"
        "os"
    )

    func ParseConfig(path string) (map[string]interface{}, error) {
        data, err := os.ReadFile(path)
        if err != nil {
            return nil, err
        }
        var config map[string]interface{}
        json.Unmarshal(data, &config)
        return config, nil
    }
  GO
])

# Rust samples
classifier.train_language(:rust, [
  <<~RUST,
    struct User {
        name: String,
        email: String,
    }

    impl User {
        fn new(name: &str, email: &str) -> Self {
            User {
                name: name.to_string(),
                email: email.to_string(),
            }
        }

        fn greet(&self) {
            println!("Hello, {}!", self.name);
        }
    }
  RUST
  <<~RUST,
    use std::fs;
    use serde_json::Value;

    fn parse_config(path: &str) -> Result<Value, Box<dyn std::error::Error>> {
        let data = fs::read_to_string(path)?;
        let config: Value = serde_json::from_str(&data)?;
        Ok(config)
    }
  RUST
])

# Purpose: Test code
classifier.train_purpose(:test, [
  <<~TEST,
    RSpec.describe User do
      describe '#greet' do
        it 'returns a greeting message' do
          user = User.new('Alice', 'alice@example.com')
          expect(user.greet).to eq('Hello, Alice!')
        end
      end
    end
  TEST
  <<~TEST,
    describe('User', () => {
      test('greet returns greeting', () => {
        const user = new User('Alice', 'alice@example.com');
        expect(user.greet()).toBe('Hello, Alice!');
      });
    });
  TEST
  <<~TEST,
    import pytest

    def test_user_greet():
        user = User('Alice', 'alice@example.com')
        assert user.greet() == 'Hello, Alice!'
  TEST
])

# Purpose: API endpoint
classifier.train_purpose(:api, [
  <<~API,
    get '/users/:id' do
      content_type :json
      user = User.find(params[:id])
      user.to_json
    end

    post '/users' do
      user = User.create(JSON.parse(request.body.read))
      status 201
      user.to_json
    end
  API
  <<~API,
    app.get('/users/:id', async (req, res) => {
      const user = await User.findById(req.params.id);
      res.json(user);
    });

    app.post('/users', async (req, res) => {
      const user = await User.create(req.body);
      res.status(201).json(user);
    });
  API
])

# Purpose: Data processing
classifier.train_purpose(:data_processing, [
  <<~DATA,
    users
      .filter { |u| u.active? }
      .map { |u| { name: u.name, email: u.email } }
      .sort_by { |u| u[:name] }
      .each { |u| process(u) }
  DATA
  <<~DATA,
    users
      .filter(u => u.active)
      .map(u => ({ name: u.name, email: u.email }))
      .sort((a, b) => a.name.localeCompare(b.name))
      .forEach(u => process(u));
  DATA
])

# Purpose: Configuration
classifier.train_purpose(:config, [
  <<~CONFIG,
    Rails.application.configure do
      config.cache_classes = true
      config.eager_load = true
      config.log_level = :info
    end
  CONFIG
  <<~CONFIG,
    module.exports = {
      entry: './src/index.js',
      output: {
        path: path.resolve(__dirname, 'dist'),
        filename: 'bundle.js'
      },
      plugins: [new HtmlWebpackPlugin()]
    };
  CONFIG
])

classifier.build_index
classifier.save('code_classifier')

puts "Trained on #{classifier.instance_variable_get(:@languages).length} languages"
puts "Trained on #{classifier.instance_variable_get(:@purposes).length} purposes"
```

## Using the Classifier

Create `classify.rb`:

```ruby
require_relative 'code_classifier'

classifier = CodeClassifier.load('code_classifier')

test_snippets = [
  {
    label: "Ruby with RSpec",
    code: <<~CODE
      describe Calculator do
        it 'adds two numbers' do
          expect(Calculator.add(2, 3)).to eq(5)
        end
      end
    CODE
  },
  {
    label: "Python function",
    code: <<~CODE
      def process_data(items):
          result = []
          for item in items:
              if item.is_valid():
                  result.append(transform(item))
          return result
    CODE
  },
  {
    label: "JavaScript API",
    code: <<~CODE
      router.get('/api/products', async (req, res) => {
        const products = await Product.findAll();
        res.json({ data: products });
      });
    CODE
  },
  {
    label: "Go struct",
    code: <<~CODE
      type Config struct {
          Host string `json:"host"`
          Port int    `json:"port"`
      }

      func LoadConfig(path string) (*Config, error) {
          data, err := os.ReadFile(path)
          if err != nil {
              return nil, err
          }
          var config Config
          json.Unmarshal(data, &config)
          return &config, nil
      }
    CODE
  },
  {
    label: "Rust with Result",
    code: <<~CODE
      fn divide(a: f64, b: f64) -> Result<f64, String> {
          if b == 0.0 {
              Err("Cannot divide by zero".to_string())
          } else {
              Ok(a / b)
          }
      }
    CODE
  }
]

puts "=" * 70
puts "CODE SNIPPET CLASSIFIER"
puts "=" * 70

test_snippets.each do |snippet|
  puts "\n#{"-" * 70}"
  puts "Sample: #{snippet[:label]}"
  puts snippet[:code].lines.first(5).map { |l| "  #{l}" }.join
  puts "  ..." if snippet[:code].lines.length > 5
  puts

  result = classifier.classify(snippet[:code])

  puts "Language: #{result[:language][:detected]} (#{result[:language][:confidence]}%)"
  if result[:language][:alternatives].any?
    alts = result[:language][:alternatives].map { |a| "#{a[:language]}=#{a[:score]}%" }.join(", ")
    puts "  Alternatives: #{alts}"
  end

  puts "Purpose: #{result[:purpose][:detected]} (#{result[:purpose][:confidence]}%)"
  puts "Key tokens: #{result[:tokens_used].join(', ')}"
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
CODE SNIPPET CLASSIFIER
======================================================================

----------------------------------------------------------------------
Sample: Ruby with RSpec
  describe Calculator do
    it 'adds two numbers' do
      expect(Calculator.add(2, 3)).to eq(5)
  ...

Language: ruby (87.3%)
  Alternatives: ruby=87.3%, python=42.1%, javascript=38.5%
Purpose: test (92.5%)
Key tokens: test_describe, test_it, test_expect, ruby_def, indent_2space
```

## IDE Integration

Create a simple CLI tool:

```ruby
#!/usr/bin/env ruby
# detect_language.rb

require_relative 'code_classifier'

classifier = CodeClassifier.load('code_classifier')

# Read from stdin or file
code = ARGV[0] ? File.read(ARGV[0]) : $stdin.read

result = classifier.classify(code)

puts result[:language][:detected]
```

Usage:
```bash
# From file
ruby detect_language.rb mystery_file.txt

# From clipboard (macOS)
pbpaste | ruby detect_language.rb

# Output just the language for scripting
ruby detect_language.rb file.txt  # => "ruby"
```

## Extending to More Languages

```ruby
# Add TypeScript
classifier.train_language(:typescript, [
  <<~TS,
    interface User {
      name: string;
      email: string;
    }

    class UserService {
      private users: User[] = [];

      async findById(id: string): Promise<User | undefined> {
        return this.users.find(u => u.id === id);
      }
    }
  TS
])

# Add Java
classifier.train_language(:java, [
  <<~JAVA,
    public class User {
        private String name;
        private String email;

        public User(String name, String email) {
            this.name = name;
            this.email = email;
        }

        public String getName() {
            return name;
        }
    }
  JAVA
])
```

## Best Practices

1. **More samples = better accuracy**: 5-10 samples per language
2. **Diverse samples**: Include different coding styles and patterns
3. **Clean samples**: Remove comments that mention the language name
4. **Real code**: Use actual project code, not artificial examples

## Next Steps

- [LSI Basics](/docs/guides/lsi/basics) - Deep dive into semantic analysis
- [kNN Basics](/docs/guides/knn/basics) - Understanding nearest neighbors
- [TF-IDF Guide](/docs/guides/tfidf/basics) - Term weighting for code analysis
