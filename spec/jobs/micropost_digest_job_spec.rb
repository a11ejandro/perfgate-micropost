require "rails_helper"

RSpec.describe MicropostDigestJob, type: :job do
  let!(:users)      { create_list(:user, 3) }
  let!(:microposts) { users.flat_map { |u| create_list(:micropost, 5, user: u) } }

  it "returns a digest hash with entries" do
    result = described_class.new.perform(limit: 10)
    expect(result[:count]).to eq(10)
    expect(result[:entries]).to all(include(:author, :content, :comments_count))
  end

  it "includes author names without N+1" do
    queries = 0
    counter = ->(*, **) { queries += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      described_class.new.perform(limit: 15)
    end
    # healthy: 1 query for microposts+users — should be 1-3 queries total
    expect(queries).to be < 5
  end
end
