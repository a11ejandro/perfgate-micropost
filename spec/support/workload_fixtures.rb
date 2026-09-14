require "rails_helper"

# Perfgate executes every observation in a clean subprocess. This helper runs
# outside Perfgate.measure and recreates the workload dataset before every
# observation. TRUNCATE ... RESTART IDENTITY avoids accumulation of dead rows
# and sequence drift. It does not flush PostgreSQL shared buffers or operating-
# system caches; perfgate.yml records that limitation explicitly.
#
# Run these with:
#   RAILS_ENV=test bundle exec perfgate run --output .perfgate/current
#
# Workload IDs must remain stable — they are the join key between baseline
# and candidate run bundles.

module WorkloadFixtures
  SEED = 12_345
  USER_COUNT = 10
  MICROPOST_COUNT = 500
  COMMENT_COUNT = 2_500
  FEATURED_COMMENT_COUNT = 200
  EPOCH = Time.utc(2024, 1, 1).freeze
  FEATURED_POST_CONTENT = "Workload post 1: rails performance test 0. #rails"
  DATASET_CONTRACT = {
    "id" => "perfgate-micropost-workload-fixtures",
    "schema_version" => "2",
    "generator_version" => "2",
    "seed" => SEED,
    "scale" => "users=10,microposts=500,comments=2500,featured_comments=200",
    "cardinality" => "users=10,microposts=500,comments=2500",
    "skew" => "first_micropost_comments=200;remaining_comments=2300_uniform_random",
    "relationships" => "each_micropost_and_comment_has_one_user;each_comment_has_one_micropost",
    "cache_state" => "database_reseeded_no_explicit_cache_flush"
  }.freeze

  module_function

  def setup
    reset_database!
    prng = Random.new(SEED)

    now = EPOCH
    User.insert_all!(USER_COUNT.times.map do |i|
      {
        name: "WUser #{i + 1}", email: "wuser#{i + 1}@example.com",
        created_at: now, updated_at: now
      }
    end)
    user_ids = User.order(:id).pluck(:id)

    Micropost.insert_all!(MICROPOST_COUNT.times.map do |i|
      timestamp = EPOCH + (i * 60)
      {
        user_id: user_ids.fetch(prng.rand(user_ids.length)),
        content: "Workload post #{i + 1}: rails performance test #{i}. #rails",
        comments_count: 0,
        created_at: timestamp,
        updated_at: timestamp
      }
    end)
    micropost_ids = Micropost.order(:id).pluck(:id)

    comments = COMMENT_COUNT.times.map do |i|
      micropost_id = if i < FEATURED_COMMENT_COUNT
                       micropost_ids.first
                     else
                       micropost_ids.fetch(1 + prng.rand(micropost_ids.length - 1))
                     end
      timestamp = EPOCH + (i * 30)
      {
        user_id: user_ids.fetch(prng.rand(user_ids.length)),
        micropost_id: micropost_id,
        content: "Workload comment #{i + 1}",
        created_at: timestamp,
        updated_at: timestamp
      }
    end
    Comment.insert_all!(comments)
    refresh_counter_cache!

    {
      users: USER_COUNT,
      microposts: MICROPOST_COUNT,
      comments: COMMENT_COUNT,
      featured_comments: FEATURED_COMMENT_COUNT
    }
  end

  def featured_micropost
    Micropost.find_by!(content: FEATURED_POST_CONTENT)
  end

  def dataset_contract
    DATASET_CONTRACT
  end

  def reset_database!
    quoted = %w[comments microposts users].map do |table|
      ActiveRecord::Base.connection.quote_table_name(table)
    end
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE #{quoted.join(', ')} RESTART IDENTITY CASCADE"
    )
  end

  def refresh_counter_cache!
    ActiveRecord::Base.connection.execute(<<~SQL)
      UPDATE microposts
      SET comments_count = (
        SELECT COUNT(*)
        FROM comments
        WHERE comments.micropost_id = microposts.id
      )
    SQL
  end
end
