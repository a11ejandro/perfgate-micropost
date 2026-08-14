class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :micropost, counter_cache: true

  validates :user,      presence: true
  validates :micropost, presence: true
  validates :content,   presence: true, length: { maximum: 500 }

  scope :oldest_first, -> { order(created_at: :asc) }
end
