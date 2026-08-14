require "rails_helper"

RSpec.describe Comment, type: :model do
  it "is valid with user, micropost, and content" do
    expect(build(:comment)).to be_valid
  end

  it "requires user" do
    expect(build(:comment, user: nil)).not_to be_valid
  end

  it "requires micropost" do
    expect(build(:comment, micropost: nil)).not_to be_valid
  end

  it "requires content" do
    expect(build(:comment, content: nil)).not_to be_valid
  end

  it "enforces content length of 500" do
    expect(build(:comment, content: "x" * 501)).not_to be_valid
  end
end
