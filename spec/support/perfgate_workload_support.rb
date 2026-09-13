require "perfgate/rspec"

# Seed stable records used by all Perfgate workloads.
# Runs once before the suite; workload specs reset transactional state between
# samples via DatabaseCleaner (truncation strategy) so the fixed records are
# re-inserted before each sample.
module PerfgateWorkloadSupport
  DATASET_SIZE = 50

  def self.seed_workload_data
    # Fixed user for comment-create workload
    @author = User.find_or_create_by!(email: "workload@example.com") do |u|
      u.name = "Workload User"
    end

    # Fixed microposts for index/show/search workloads
    @microposts = DATASET_SIZE.times.map do |i|
      Micropost.find_or_create_by!(
        user:    @author,
        content: "Workload micropost #{i + 1}: rails performance test. #rails"
      )
    end

    # Fixed comments so show-page has data to paginate
    mp = @microposts.first
    10.times do |i|
      Comment.find_or_create_by!(
        user:      @author,
        micropost: mp,
        content:   "Workload comment #{i + 1}"
      )
    end
  end

  def self.author
    @author ||= User.find_by!(email: "workload@example.com")
  end

  def self.first_micropost
    @microposts&.first || Micropost.includes(:user).order(:id).first!
  end
end
