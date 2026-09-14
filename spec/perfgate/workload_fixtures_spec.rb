require "rails_helper"
require "yaml"

RSpec.describe WorkloadFixtures do
  self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

  it "recreates the declared dataset and resets database identities" do
    first_result = described_class.setup
    first_ids = [User.minimum(:id), Micropost.minimum(:id), Comment.minimum(:id)]

    expect(first_result).to eq(
      users: 10, microposts: 500, comments: 2_500, featured_comments: 200
    )
    expect(User.count).to eq(10)
    expect(Micropost.count).to eq(500)
    expect(Comment.count).to eq(2_500)
    expect(described_class.featured_micropost.comments.count).to eq(200)

    described_class.setup
    expect([User.minimum(:id), Micropost.minimum(:id), Comment.minimum(:id)]).to eq(first_ids)
  end

  it "matches the evidence contract declared in perfgate.yml" do
    config = YAML.safe_load(File.read(Rails.root.join("perfgate.yml")))

    expect(config.fetch("dataset")).to include(described_class.dataset_contract)
  end
end
