require "rails_helper"

# Baseline workload specs run against a persistent seeded dataset.
# DatabaseCleaner uses :truncation + re-seed per workload example so each
# sample begins from identical state.
#
# Run these with:
#   RAILS_ENV=test bundle exec baseline run --output .baseline/current
#
# Workload IDs must remain stable — they are the join key between baseline
# and candidate run bundles.

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
  end
end

# Small deterministic fixture used by all workload specs.
# Inserted once; the transaction rollback between examples keeps state clean.
module WorkloadFixtures
  PRNG = Random.new(99)

  def self.setup(user_count: 10, post_count: 50, comment_count: 200)
    epoch = Time.utc(2024, 1, 1)

    users = user_count.times.map do |i|
      User.create!(
        name:  "WUser #{i + 1}",
        email: "wuser#{i + 1}@example.com"
      )
    end

    posts = post_count.times.map do |i|
      Micropost.create!(
        user:    users[PRNG.rand(users.size)],
        content: "Workload post #{i + 1}: rails performance test #{PRNG.rand(1000)}. #rails",
        created_at: epoch + i * 3600,
        updated_at: epoch + i * 3600
      )
    end

    comment_count.times do |i|
      Comment.create!(
        user:      users[PRNG.rand(users.size)],
        micropost: posts[PRNG.rand(posts.size)],
        content:   "Workload comment #{i + 1}: great work!"
      )
    end

    { users: users, posts: posts }
  end
end
