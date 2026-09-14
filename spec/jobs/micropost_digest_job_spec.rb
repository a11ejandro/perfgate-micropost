require "rails_helper"

RSpec.describe MicropostDigestJob, type: :job do
  let!(:users)      { create_list(:user, 3) }
  let!(:microposts) { users.flat_map { |u| create_list(:micropost, 5, user: u) } }

  it "returns a digest hash with entries" do
    result = described_class.new.perform(limit: 10)
    expect(result[:count]).to eq(10)
    expect(result[:entries]).to all(include(:author, :content, :comments_count))
  end

end
