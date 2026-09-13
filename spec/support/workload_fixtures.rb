require "rails_helper"

# Perfgate workload specs run against a persistent seeded dataset.
# The workload examples opt out of Rails transactional fixtures because
# Perfgate runs them in forked child processes. This helper therefore
# resets and reseeds the small workload dataset before each sample so
# every measurement starts from identical state.
#
# Run these with:
#   RAILS_ENV=test bundle exec perfgate run --output .perfgate/current
#
# Workload IDs must remain stable — they are the join key between baseline
# and candidate run bundles.

# Small deterministic fixture used by all workload specs.
# Inserted once; the transaction rollback between examples keeps state clean.
module WorkloadFixtures
  def self.setup(user_count: 10, post_count: 50, comment_count: 200)
    epoch = Time.utc(2024, 1, 1)
    prng = Random.new(99)

    Comment.delete_all
    Micropost.delete_all
    User.delete_all

    users = user_count.times.map do |i|
      User.find_or_create_by!(email: "wuser#{i + 1}@example.com") do |u|
        u.name = "WUser #{i + 1}"
      end
    end

    posts = post_count.times.map do |i|
      content = "Workload post #{i + 1}: rails performance test #{i}. #rails"
      Micropost.find_or_create_by!(user: users[prng.rand(users.size)], content: content) do |mp|
        mp.created_at = epoch + i * 3600
        mp.updated_at = epoch + i * 3600
      end
    end

    comment_count.times do |i|
      Comment.find_or_create_by!(
        user:      users[prng.rand(users.size)],
        micropost: posts[prng.rand(posts.size)],
        content:   "Workload comment #{i + 1}"
      )
    end

    { users: users, posts: posts }
  end
end
