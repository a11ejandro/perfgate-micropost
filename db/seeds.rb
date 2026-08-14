# Deterministic seed for baseline-micropost reference application.
#
# Uses a fixed PRNG so every run produces logically equivalent data.
# Dataset version is exposed as BASELINE_DATASET_VERSION for Baseline fingerprinting.
#
# Target (configurable via ENV):
#   SAMPLE_USERS=100, SAMPLE_MICROPOSTS=5000, SAMPLE_COMMENTS=50000
#
# Usage:
#   bundle exec rails db:seed
#   SAMPLE_USERS=10 SAMPLE_MICROPOSTS=100 SAMPLE_COMMENTS=500 bundle exec rails db:seed

DATASET_VERSION = "micropost-v1"
PRNG = Random.new(42)

SAMPLE_USERS      = ENV.fetch("SAMPLE_USERS",      "100").to_i
SAMPLE_MICROPOSTS = ENV.fetch("SAMPLE_MICROPOSTS", "5000").to_i
SAMPLE_COMMENTS   = ENV.fetch("SAMPLE_COMMENTS",   "50000").to_i

# Fixed epoch so all timestamps are deterministic regardless of when seed runs.
EPOCH = Time.utc(2024, 1, 1, 0, 0, 0).freeze

puts "Seeding #{SAMPLE_USERS} users, #{SAMPLE_MICROPOSTS} microposts, #{SAMPLE_COMMENTS} comments..."
puts "Dataset version: #{DATASET_VERSION}"

ActiveRecord::Base.transaction do
  # ── Users ────────────────────────────────────────────────────────────────
  User.delete_all

  user_rows = SAMPLE_USERS.times.map do |i|
    n      = i + 1
    offset = PRNG.rand(0..3_000_000)
    { name: "User #{n}", email: "user#{n}@example.com",
      created_at: EPOCH + offset, updated_at: EPOCH + offset }
  end
  User.insert_all!(user_rows)
  user_ids = User.order(:id).pluck(:id)
  puts "  #{user_ids.size} users inserted"

  # ── Microposts ────────────────────────────────────────────────────────────
  Micropost.delete_all

  adjectives = %w[quick lazy happy curious brave clever bold calm kind warm]
  nouns      = %w[rails gem feature test bug refactor deploy migration cache query]
  verbs      = %w[improves simplifies breaks fixes ships accelerates reveals touches updates handles]

  micropost_rows = SAMPLE_MICROPOSTS.times.map do |i|
    n       = i + 1
    user_id = user_ids[PRNG.rand(user_ids.size)]
    offset  = PRNG.rand(0..5_000_000)
    content = "Micropost #{n}: The #{adjectives[PRNG.rand(10)]} " \
              "#{nouns[PRNG.rand(10)]} #{verbs[PRNG.rand(10)]} everything. #rails"
    { user_id: user_id, content: content, comments_count: 0,
      created_at: EPOCH + offset, updated_at: EPOCH + offset }
  end
  Micropost.insert_all!(micropost_rows)
  micropost_ids = Micropost.order(:id).pluck(:id)
  puts "  #{micropost_ids.size} microposts inserted"

  # ── Comments ──────────────────────────────────────────────────────────────
  Comment.delete_all

  phrases = [
    "Great point!", "Totally agree.", "Interesting perspective.",
    "Could you elaborate?", "This helped me.", "Nice catch.",
    "Worth noting for future reference.", "Exactly what I needed.",
    "I had the same issue.", "Thanks for sharing this."
  ]

  comment_rows = SAMPLE_COMMENTS.times.map do |i|
    n            = i + 1
    user_id      = user_ids[PRNG.rand(user_ids.size)]
    micropost_id = micropost_ids[PRNG.rand(micropost_ids.size)]
    offset       = PRNG.rand(0..8_000_000)
    { user_id: user_id, micropost_id: micropost_id,
      content: "Comment #{n}: #{phrases[PRNG.rand(phrases.size)]}",
      created_at: EPOCH + offset, updated_at: EPOCH + offset }
  end
  Comment.insert_all!(comment_rows)
  puts "  #{Comment.count} comments inserted"

  # Recompute counter cache — insert_all bypasses callbacks.
  ActiveRecord::Base.connection.execute(<<~SQL)
    UPDATE microposts
    SET    comments_count = (
             SELECT COUNT(*) FROM comments WHERE comments.micropost_id = microposts.id
           )
  SQL
  puts "  counter cache updated"
end

puts "Done. BASELINE_DATASET_VERSION=#{DATASET_VERSION}"
