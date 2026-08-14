class Micropost < ApplicationRecord
  belongs_to :user
  has_many   :comments, dependent: :destroy

  validates :user,    presence: true
  validates :content, presence: true, length: { maximum: 500 }

  scope :newest_first, -> { order(created_at: :desc) }
end
