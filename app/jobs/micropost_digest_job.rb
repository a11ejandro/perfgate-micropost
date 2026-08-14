class MicropostDigestJob < ApplicationJob
  queue_as :default

  # Loads recent microposts with authors and comment counts in two queries
  # (one for microposts+users via includes, one for the limit), then builds
  # a plain structured digest. No email, no external calls.
  def perform(limit: 50)
    microposts = Micropost.includes(:user)
                          .newest_first
                          .limit(limit)

    entries = microposts.map do |mp|
      {
        id:             mp.id,
        author:         mp.user.name,
        content:        mp.content,
        comments_count: mp.comments_count,
        created_at:     mp.created_at.iso8601
      }
    end

    { generated_at: Time.now.utc.iso8601, count: entries.size, entries: entries }
  end
end
