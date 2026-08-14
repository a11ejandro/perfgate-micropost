class Comment < ApplicationRecord
  belongs_to :user
  # REGRESSION: counter_cache removed; an after_create callback recounts instead.
  belongs_to :micropost

  validates :user,      presence: true
  validates :micropost, presence: true
  validates :content,   presence: true, length: { maximum: 500 }

  scope :oldest_first, -> { order(created_at: :asc) }

  after_create :recount_comments

  private

  def recount_comments
    micropost.update!(comments_count: micropost.comments.count)
  end
end
