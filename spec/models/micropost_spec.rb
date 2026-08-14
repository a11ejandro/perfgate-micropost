require "rails_helper"

RSpec.describe Micropost, type: :model do
  it "is valid with user and content" do
    expect(build(:micropost)).to be_valid
  end

  it "requires user" do
    expect(build(:micropost, user: nil)).not_to be_valid
  end

  it "requires content" do
    expect(build(:micropost, content: nil)).not_to be_valid
  end

  it "enforces content length of 500" do
    expect(build(:micropost, content: "x" * 501)).not_to be_valid
  end

  it "has a comments_count of 0 by default" do
    mp = create(:micropost)
    expect(mp.comments_count).to eq(0)
  end

  it "increments comments_count via counter cache" do
    mp = create(:micropost)
    create(:comment, micropost: mp)
    expect(mp.reload.comments_count).to eq(1)
  end
end
