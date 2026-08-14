class MicropostDigestJob < ApplicationJob
  queue_as :default

  def perform(limit: 50)
    # REGRESSION: loads microposts without eager-loading users.
    # Each mp.user.name below fires a separate SELECT.
    microposts = Micropost.newest_first.limit(limit)

    entries = microposts.map do |mp|
      {
        id:             mp.id,
        author:         mp.user.name,       # N+1: one query per micropost
        content:        mp.content,
        comments_count: mp.comments.count,  # N+1: one COUNT per micropost
        created_at:     mp.created_at.iso8601
      }
    end

    { generated_at: Time.now.utc.iso8601, count: entries.size, entries: entries }
  end
end
