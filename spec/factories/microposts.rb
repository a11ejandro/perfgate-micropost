FactoryBot.define do
  factory :micropost do
    association :user
    sequence(:content) { |n| "Micropost #{n}: a test post about rails performance." }
  end
end
