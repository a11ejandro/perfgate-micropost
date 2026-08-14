class MicropostDigestJob < ApplicationJob
  queue_as :default

  # REGRESSION: excessive object allocation — serializes each entry to JSON and
  # parses it back, duplicates the content string, and builds redundant
  # intermediate hashes. SQL queries remain correct (same as main).
  def perform(limit: 50)
    microposts = Micropost.includes(:user)
                          .newest_first
                          .limit(limit)

    entries = microposts.map do |mp|
      raw = {
        id:             mp.id,
        author:         mp.user.name.dup,
        content:        mp.content.dup,
        comments_count: mp.comments_count,
        created_at:     mp.created_at.iso8601
      }

      # Unnecessary round-trip through JSON to "normalize" the entry.
      normalized = JSON.parse(raw.to_json)

      # Rebuild from the normalized copy — doubles intermediate allocations.
      {
        id:             normalized["id"],
        author:         normalized["author"].dup,
        content:        normalized["content"].dup,
        comments_count: normalized["comments_count"],
        created_at:     normalized["created_at"]
      }
    end

    { generated_at: Time.now.utc.iso8601, count: entries.size, entries: entries }
  end
end
