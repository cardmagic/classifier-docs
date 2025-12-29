---
title: "Chatbot Intent Detection"
description: "Build an intent classifier for chatbots that understands user messages and routes to appropriate handlers."
difficulty: intermediate
order: 8
---

# Chatbot Intent Detection

Build an intent detection system that understands what users want from their messages, even when they phrase things differently. Using kNN, we get interpretable results and can easily add new intents.

## What You'll Learn

- Classifying user intents from natural language
- Handling multiple ways to express the same intent
- Confidence thresholds for fallback handling
- Building a practical chatbot component

## Why kNN for Intents?

- **Easy to update**: Add new example phrases without retraining
- **Interpretable**: See which examples matched
- **Handles variations**: Similar phrases match even if not exact
- **Confidence scores**: Know when to ask for clarification

## Project Setup

```bash
mkdir intent_classifier && cd intent_classifier
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## The Intent Classifier

Create `intent_classifier.rb`:

```ruby
require 'classifier'
require 'json'

class IntentClassifier
  FALLBACK_THRESHOLD = 0.4  # Minimum confidence to classify

  def initialize(k: 3)
    @knn = Classifier::KNN.new(k: k, weighted: true)
    @intents = {}  # intent_name => {description:, handler:, examples:}
  end

  # Register an intent with example phrases
  def register_intent(name, examples:, description: nil, handler: nil)
    name = name.to_sym
    @intents[name] = {
      description: description || name.to_s,
      handler: handler,
      examples: Array(examples)
    }

    # Add examples to kNN
    @knn.add(name => examples)
  end

  # Classify a user message
  def classify(message)
    result = @knn.classify_with_neighbors(message)

    return fallback_result(message) if result[:category].nil?

    intent = result[:category].to_sym
    confidence = result[:confidence]

    # Check if confidence is too low
    return fallback_result(message) if confidence < FALLBACK_THRESHOLD

    {
      intent: intent,
      confidence: (confidence * 100).round(1),
      description: @intents[intent]&.dig(:description),
      matched_examples: extract_matched_examples(result[:neighbors]),
      raw_result: result
    }
  end

  # Classify and execute handler if available
  def handle(message, context: {})
    classification = classify(message)

    if classification[:intent] == :fallback
      return { response: "I'm not sure I understand. Could you rephrase that?", classification: classification }
    end

    handler = @intents[classification[:intent]]&.dig(:handler)

    if handler
      response = handler.call(message, context)
      { response: response, classification: classification }
    else
      { response: nil, classification: classification }
    end
  end

  # Get all registered intents
  def intents
    @intents.transform_values { |v| v[:description] }
  end

  # Get example phrases for an intent
  def examples_for(intent)
    @intents[intent.to_sym]&.dig(:examples) || []
  end

  def save(path)
    data = {
      intents: @intents.transform_values { |v| v.reject { |k, _| k == :handler } },
      knn: JSON.parse(@knn.to_json)
    }
    File.write(path, data.to_json)
  end

  def self.load(path, handlers: {})
    classifier = new
    data = JSON.parse(File.read(path), symbolize_names: true)

    data[:intents].each do |name, intent_data|
      classifier.register_intent(
        name,
        examples: intent_data[:examples],
        description: intent_data[:description],
        handler: handlers[name]
      )
    end

    classifier
  end

  private

  def fallback_result(message)
    {
      intent: :fallback,
      confidence: 0,
      description: "Could not understand intent",
      matched_examples: [],
      original_message: message
    }
  end

  def extract_matched_examples(neighbors)
    neighbors.first(3).map do |n|
      {
        example: n[:item],
        intent: n[:category],
        similarity: (n[:similarity] * 100).round(1)
      }
    end
  end
end
```

## Defining Intents

Create `setup_intents.rb`:

```ruby
require_relative 'intent_classifier'

classifier = IntentClassifier.new(k: 3)

# Greeting intent
classifier.register_intent(:greeting,
  description: "User is saying hello",
  examples: [
    "hello",
    "hi there",
    "hey",
    "good morning",
    "good afternoon",
    "hi",
    "howdy",
    "greetings",
  ]
)

# Farewell intent
classifier.register_intent(:farewell,
  description: "User is saying goodbye",
  examples: [
    "bye",
    "goodbye",
    "see you later",
    "talk to you later",
    "have a good day",
    "bye bye",
    "see ya",
    "gotta go",
  ]
)

# Help intent
classifier.register_intent(:help,
  description: "User needs assistance",
  examples: [
    "I need help",
    "can you help me",
    "help please",
    "I'm stuck",
    "I don't understand",
    "how does this work",
    "what can you do",
    "I have a question",
  ]
)

# Order status intent
classifier.register_intent(:order_status,
  description: "User wants to check order status",
  examples: [
    "where is my order",
    "check my order status",
    "when will my package arrive",
    "track my order",
    "order tracking",
    "delivery status",
    "when will it ship",
    "has my order shipped",
  ]
)

# Cancel order intent
classifier.register_intent(:cancel_order,
  description: "User wants to cancel an order",
  examples: [
    "cancel my order",
    "I want to cancel",
    "how do I cancel",
    "stop my order",
    "don't send my order",
    "I changed my mind about my order",
    "cancel order please",
  ]
)

# Refund intent
classifier.register_intent(:refund,
  description: "User wants a refund",
  examples: [
    "I want a refund",
    "can I get my money back",
    "refund please",
    "I want to return this",
    "how do I get a refund",
    "return and refund",
    "money back guarantee",
  ]
)

# Account issues intent
classifier.register_intent(:account_help,
  description: "User has account-related issues",
  examples: [
    "I can't log in",
    "forgot my password",
    "reset password",
    "account locked",
    "can't access my account",
    "login problems",
    "change my email",
    "update my account",
  ]
)

# Pricing intent
classifier.register_intent(:pricing,
  description: "User asking about prices",
  examples: [
    "how much does it cost",
    "what's the price",
    "pricing information",
    "is there a discount",
    "do you have any deals",
    "how much is shipping",
    "what are your rates",
  ]
)

classifier.save('intents.json')
puts "Saved #{classifier.intents.length} intents:"
classifier.intents.each { |name, desc| puts "  - #{name}: #{desc}" }
```

## Using the Classifier

Create `chat.rb`:

```ruby
require_relative 'intent_classifier'

# Define handlers for each intent
handlers = {
  greeting: ->(msg, ctx) { "Hello! How can I help you today?" },
  farewell: ->(msg, ctx) { "Goodbye! Have a great day!" },
  help: ->(msg, ctx) { "I can help with orders, refunds, account issues, and more. What do you need?" },
  order_status: ->(msg, ctx) { "I'll look up your order. What's your order number?" },
  cancel_order: ->(msg, ctx) { "I can help cancel your order. Please provide the order number." },
  refund: ->(msg, ctx) { "I understand you want a refund. Let me connect you with our returns team." },
  account_help: ->(msg, ctx) { "For account issues, please visit our password reset page or contact support." },
  pricing: ->(msg, ctx) { "Our pricing starts at $9.99/month. Would you like more details?" },
}

classifier = IntentClassifier.load('intents.json', handlers: handlers)

# Test messages
test_messages = [
  "Hi there!",
  "I need help with something",
  "Where's my package?",
  "I want my money back",
  "What's the cost?",
  "asdfghjkl",  # Gibberish - should fallback
  "bye bye",
  "my login doesn't work",
]

puts "=" * 60
puts "CHATBOT INTENT DETECTION"
puts "=" * 60

test_messages.each do |message|
  puts "\nUser: #{message}"

  result = classifier.handle(message)
  classification = result[:classification]

  puts "Intent: #{classification[:intent]} (#{classification[:confidence]}%)"

  if result[:response]
    puts "Bot: #{result[:response]}"
  end

  if classification[:matched_examples].any?
    puts "Matched: #{classification[:matched_examples].first[:example]} (#{classification[:matched_examples].first[:similarity]}%)"
  end
end

# Interactive mode
puts "\n#{"=" * 60}"
puts "Chat with the bot! (type 'quit' to exit)"
puts "=" * 60

loop do
  print "\nYou: "
  input = gets&.chomp
  break if input.nil? || input.downcase == 'quit'
  next if input.empty?

  result = classifier.handle(input)

  if result[:response]
    puts "Bot: #{result[:response]}"
  else
    puts "Bot: [Intent: #{result[:classification][:intent]}] (no handler defined)"
  end
end
```

Run it:

```bash
ruby setup_intents.rb
ruby chat.rb
```

Output:
```
============================================================
CHATBOT INTENT DETECTION
============================================================

User: Hi there!
Intent: greeting (92.1%)
Bot: Hello! How can I help you today?
Matched: hi there (98.5%)

User: Where's my package?
Intent: order_status (87.4%)
Bot: I'll look up your order. What's your order number?
Matched: where is my order (91.2%)

User: asdfghjkl
Intent: fallback (0%)
Bot: I'm not sure I understand. Could you rephrase that?
```

## Adding New Intents On-the-Fly

```ruby
# Add a new intent without retraining
classifier.register_intent(:complaint,
  description: "User has a complaint",
  examples: [
    "I want to complain",
    "this is unacceptable",
    "I'm very unhappy",
    "worst service ever",
    "I need to speak to a manager",
  ],
  handler: ->(msg, ctx) { "I'm sorry to hear that. Let me connect you with a supervisor." }
)

# Save updated intents
classifier.save('intents.json')
```

## Integration with Chat Frameworks

```ruby
# Slack bot example
class SlackBot
  def initialize
    @classifier = IntentClassifier.load('intents.json', handlers: slack_handlers)
  end

  def handle_message(event)
    message = event['text']
    result = @classifier.handle(message, context: { user: event['user'] })

    if result[:response]
      slack_client.chat_postMessage(
        channel: event['channel'],
        text: result[:response]
      )
    else
      # Log unhandled intent for review
      log_unhandled(event, result[:classification])
    end
  end

  private

  def slack_handlers
    {
      greeting: ->(msg, ctx) { "Hey <@#{ctx[:user]}>! How can I help?" },
      # ... more handlers
    }
  end
end
```

## Improving Intent Detection

1. **Add more examples**: 10-20 examples per intent improves accuracy
2. **Handle edge cases**: Add examples for common misspellings
3. **Use context**: Pass user context to handlers for personalization
4. **Log fallbacks**: Review unclassified messages to discover new intents
5. **Adjust k**: Higher k = more stable but may miss nuance

## Next Steps

- [kNN Basics](/docs/guides/knn/basics) - Deep dive into k-Nearest Neighbors
- [Persistence Guide](/docs/guides/persistence/basics) - Production storage strategies
