---
title: "Duplicate Ticket Detector"
description: "Build a system to detect duplicate support tickets using LSI semantic similarity and TF-IDF weighting."
difficulty: intermediate
classifiers: [lsi, tfidf]
order: 8
---

# Duplicate Ticket Detector

Support teams waste hours on duplicate tickets. Build a detector that finds semantically similar tickets—even when they use different words to describe the same problem.

## What You'll Learn

- Combining LSI and TF-IDF for better matching
- Finding similar documents with confidence thresholds
- Building a practical support tool

## Why LSI + TF-IDF?

- **LSI** finds semantic similarity ("can't login" ≈ "authentication failed")
- **TF-IDF** weights important terms higher (error codes, product names)
- Together they catch duplicates that keyword matching would miss

## Project Setup

```bash
mkdir duplicate_detector && cd duplicate_detector
```

```ruby
# Gemfile
source 'https://rubygems.org'
gem 'classifier'
```

## The Duplicate Detector

Create `duplicate_detector.rb`:

```ruby
require 'classifier'
require 'json'

class DuplicateDetector
  SIMILARITY_THRESHOLD = 0.6  # 60% similar = likely duplicate

  def initialize
    @lsi = Classifier::LSI.new(auto_rebuild: false)
    @tickets = {}  # id => ticket data
    @tfidf = Classifier::TFIDF.new(min_df: 1, sublinear_tf: true)
    @corpus = []
  end

  # Add a resolved/existing ticket
  def add_ticket(id, subject:, body:, status: 'open')
    content = "#{subject} #{body}"
    @tickets[id] = {
      id: id,
      subject: subject,
      body: body,
      status: status,
      content: content
    }
    @corpus << content
    @lsi.add_item(content, id)
  end

  # Rebuild index after batch additions
  def rebuild_index
    @lsi.build_index
    @tfidf.fit(@corpus) if @corpus.any?
  end

  # Check if a new ticket is a duplicate
  def find_duplicates(subject:, body:, limit: 5)
    content = "#{subject} #{body}"

    # Get LSI similarity scores
    similar = @lsi.find_related(content, limit * 2)
    return [] if similar.empty?

    # Calculate combined scores with TF-IDF boost
    new_vector = @tfidf.fitted? ? @tfidf.transform(content) : {}

    results = similar.filter_map do |ticket_content|
      ticket_id = @lsi.categories_for(ticket_content).first
      ticket = @tickets[ticket_id]
      next unless ticket

      # Base LSI similarity
      lsi_score = calculate_lsi_similarity(content, ticket_content)

      # TF-IDF boost for shared important terms
      tfidf_boost = calculate_tfidf_overlap(new_vector, ticket[:content])

      # Combined score (weighted average)
      combined_score = (lsi_score * 0.7) + (tfidf_boost * 0.3)

      next if combined_score < SIMILARITY_THRESHOLD

      {
        ticket_id: ticket_id,
        subject: ticket[:subject],
        status: ticket[:status],
        similarity: (combined_score * 100).round(1),
        lsi_score: (lsi_score * 100).round(1),
        tfidf_boost: (tfidf_boost * 100).round(1),
        excerpt: ticket[:body][0..100]
      }
    end

    results.sort_by { |r| -r[:similarity] }.first(limit)
  end

  # Quick check: is this likely a duplicate?
  def duplicate?(subject:, body:, threshold: SIMILARITY_THRESHOLD)
    duplicates = find_duplicates(subject: subject, body: body, limit: 1)
    duplicates.any? && duplicates.first[:similarity] >= (threshold * 100)
  end

  def save(path)
    rebuild_index
    data = {
      tickets: @tickets,
      corpus: @corpus
    }
    File.write(path, data.to_json)
  end

  def self.load(path)
    detector = new
    data = JSON.parse(File.read(path), symbolize_names: true)

    data[:tickets].each do |id, ticket|
      detector.add_ticket(
        id.to_s,
        subject: ticket[:subject],
        body: ticket[:body],
        status: ticket[:status]
      )
    end
    detector.rebuild_index
    detector
  end

  private

  def calculate_lsi_similarity(content1, content2)
    # Use LSI's proximity calculation
    related = @lsi.proximity_array_for_content(content1)
    match = related.find { |item, _| item == content2 }
    match ? match[1] : 0.0
  end

  def calculate_tfidf_overlap(vector1, content2)
    return 0.0 unless @tfidf.fitted?

    vector2 = @tfidf.transform(content2)
    return 0.0 if vector1.empty? || vector2.empty?

    # Cosine similarity of TF-IDF vectors
    shared_terms = vector1.keys & vector2.keys
    return 0.0 if shared_terms.empty?

    dot_product = shared_terms.sum { |term| vector1[term] * vector2[term] }
    dot_product  # Already normalized
  end
end
```

## Loading Historical Tickets

Create `seed_tickets.rb`:

```ruby
require_relative 'duplicate_detector'

detector = DuplicateDetector.new

# Historical support tickets
tickets = [
  {
    id: "TICK-001",
    subject: "Cannot login to my account",
    body: "I'm trying to login but it says invalid password. I've reset it twice already. Using Chrome on Mac.",
    status: "resolved"
  },
  {
    id: "TICK-002",
    subject: "Payment failed",
    body: "My credit card was charged but the order shows as failed. Transaction ID: TXN-12345.",
    status: "resolved"
  },
  {
    id: "TICK-003",
    subject: "App crashes on startup",
    body: "iOS app version 2.3.1 crashes immediately after splash screen. iPhone 14, iOS 17.",
    status: "resolved"
  },
  {
    id: "TICK-004",
    subject: "Password reset not working",
    body: "The reset password email never arrives. Checked spam folder. Email is correct.",
    status: "resolved"
  },
  {
    id: "TICK-005",
    subject: "Charged twice for subscription",
    body: "I see two charges on my credit card for this month's subscription. Please refund one.",
    status: "resolved"
  },
  {
    id: "TICK-006",
    subject: "Mobile app force closes",
    body: "Android app keeps crashing when I try to open it. Pixel 7, Android 14. Tried reinstalling.",
    status: "open"
  },
  {
    id: "TICK-007",
    subject: "Can't access account - authentication error",
    body: "Getting 'authentication failed' error when trying to sign in. Password is definitely correct.",
    status: "open"
  },
  {
    id: "TICK-008",
    subject: "Export feature not working",
    body: "When I click export to CSV, nothing happens. No download, no error. Firefox browser.",
    status: "resolved"
  },
  {
    id: "TICK-009",
    subject: "Billing shows wrong amount",
    body: "My invoice shows $99 but my plan is $49/month. Started this billing cycle.",
    status: "open"
  },
  {
    id: "TICK-010",
    subject: "Two-factor authentication locked out",
    body: "Lost my phone with authenticator app. Can't login now. Need to disable 2FA.",
    status: "resolved"
  },
]

tickets.each do |ticket|
  detector.add_ticket(
    ticket[:id],
    subject: ticket[:subject],
    body: ticket[:body],
    status: ticket[:status]
  )
  puts "Added: #{ticket[:id]} - #{ticket[:subject]}"
end

detector.save('tickets.json')
puts "\nSaved #{tickets.length} tickets to tickets.json"
```

## Checking for Duplicates

Create `check_duplicate.rb`:

```ruby
require_relative 'duplicate_detector'

detector = DuplicateDetector.load('tickets.json')

# New incoming tickets to check
new_tickets = [
  {
    subject: "Login not working",
    body: "I can't sign into my account. Says wrong password but I know it's right."
  },
  {
    subject: "App won't open on iPhone",
    body: "Just updated to iOS 17 and now the app crashes on launch. iPhone 14 Pro."
  },
  {
    subject: "Need to update credit card",
    body: "How do I change my payment method? Want to use a different card."
  },
  {
    subject: "Double charged this month",
    body: "Seeing duplicate subscription charges on my bank statement."
  }
]

new_tickets.each do |ticket|
  puts "=" * 60
  puts "NEW TICKET: #{ticket[:subject]}"
  puts "-" * 60

  duplicates = detector.find_duplicates(
    subject: ticket[:subject],
    body: ticket[:body],
    limit: 3
  )

  if duplicates.empty?
    puts "✓ No duplicates found - this appears to be a new issue"
  else
    puts "⚠ Potential duplicates found:\n\n"
    duplicates.each do |dup|
      puts "  #{dup[:ticket_id]} (#{dup[:similarity]}% similar)"
      puts "  Subject: #{dup[:subject]}"
      puts "  Status: #{dup[:status]}"
      puts "  Scores: LSI=#{dup[:lsi_score]}%, TF-IDF=#{dup[:tfidf_boost]}%"
      puts "  Preview: #{dup[:excerpt]}..."
      puts
    end
  end
  puts
end
```

Run it:

```bash
ruby seed_tickets.rb
ruby check_duplicate.rb
```

Output:
```
============================================================
NEW TICKET: Login not working
------------------------------------------------------------
⚠ Potential duplicates found:

  TICK-007 (84.2% similar)
  Subject: Can't access account - authentication error
  Status: open
  Scores: LSI=82.1%, TF-IDF=89.3%
  Preview: Getting 'authentication failed' error when trying to sign in...

  TICK-001 (76.8% similar)
  Subject: Cannot login to my account
  Status: resolved
  Scores: LSI=78.4%, TF-IDF=72.1%
  Preview: I'm trying to login but it says invalid password...

============================================================
NEW TICKET: App won't open on iPhone
------------------------------------------------------------
⚠ Potential duplicates found:

  TICK-003 (89.1% similar)
  Subject: App crashes on startup
  Status: resolved
  Scores: LSI=91.2%, TF-IDF=84.5%
  Preview: iOS app version 2.3.1 crashes immediately after splash screen...
```

## Integration with Support System

```ruby
class SupportTicket
  attr_accessor :subject, :body, :duplicate_of

  def self.detector
    @detector ||= DuplicateDetector.load('tickets.json')
  end

  def check_duplicates
    self.class.detector.find_duplicates(
      subject: subject,
      body: body
    )
  end

  def likely_duplicate?
    duplicates = check_duplicates
    duplicates.any? && duplicates.first[:similarity] > 75
  end

  def auto_link_duplicate!
    duplicates = check_duplicates
    if duplicates.any? && duplicates.first[:similarity] > 85
      self.duplicate_of = duplicates.first[:ticket_id]
      true
    else
      false
    end
  end
end

# In your ticket creation flow:
ticket = SupportTicket.new
ticket.subject = params[:subject]
ticket.body = params[:body]

if ticket.likely_duplicate?
  # Show warning to user or agent
  duplicates = ticket.check_duplicates
  flash[:warning] = "This may be a duplicate of #{duplicates.first[:ticket_id]}"
end
```

## Tuning the Detector

Adjust thresholds based on your needs:

```ruby
# More aggressive duplicate detection (fewer false negatives)
SIMILARITY_THRESHOLD = 0.5  # 50%

# More conservative (fewer false positives)
SIMILARITY_THRESHOLD = 0.75  # 75%

# Adjust LSI vs TF-IDF weighting
combined_score = (lsi_score * 0.5) + (tfidf_boost * 0.5)  # Equal weight
combined_score = (lsi_score * 0.9) + (tfidf_boost * 0.1)  # Mostly semantic
```

## Best Practices

1. **Rebuild index periodically**: After adding many tickets, call `rebuild_index`
2. **Include resolved tickets**: They help catch duplicates of known issues
3. **Tune thresholds**: Start conservative (75%+), lower if missing duplicates
4. **Human review**: Use as a suggestion tool, not automatic merging

## Next Steps

- [LSI Basics](/docs/guides/lsi/basics) - Deep dive into semantic similarity
- [TF-IDF Guide](/docs/guides/tfidf/basics) - Understanding term weighting
