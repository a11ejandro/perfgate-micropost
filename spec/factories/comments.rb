FactoryBot.define do
  factory :comment do
    association :user
    association :micropost
    sequence(:content) { |n| "Comment #{n}: great point!" }
  end
end
