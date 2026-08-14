require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with name and unique email" do
    expect(build(:user)).to be_valid
  end

  it "requires name" do
    expect(build(:user, name: nil)).not_to be_valid
  end

  it "requires email" do
    expect(build(:user, email: nil)).not_to be_valid
  end

  it "requires unique email" do
    create(:user, email: "dup@example.com")
    expect(build(:user, email: "dup@example.com")).not_to be_valid
  end
end
