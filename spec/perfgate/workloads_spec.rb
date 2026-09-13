require "rails_helper"

# Perfgate workload specs.
#
# Each example is tagged `perfgate: { id: "..." }` which both marks it for
# Perfgate discovery AND sets a stable workload ID independent of description
# text changes.
#
# Setup runs OUTSIDE Perfgate.measure; assertions run OUTSIDE the measured block.
#
# Run with:
#   RAILS_ENV=test PERFGATE_DATASET_VERSION=micropost-v1 \
#     bundle exec perfgate run --output .perfgate/current

RSpec.describe "Perfgate workloads", type: :request do
  self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

  before(:each) { WorkloadFixtures.setup }

  # ── microposts.index ──────────────────────────────────────────────────────

  describe "Micropost index",
           perfgate: { id: "microposts.index" } do
    it "renders the first page" do
      Perfgate.measure { get "/microposts" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── microposts.show ───────────────────────────────────────────────────────

  describe "Micropost show",
           perfgate: { id: "microposts.show" } do
    it "renders a micropost with comments" do
      mp = Micropost.includes(:comments).order(:id).first!
      Perfgate.measure { get "/microposts/#{mp.id}" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── microposts.search ─────────────────────────────────────────────────────

  describe "Micropost search",
           perfgate: { id: "microposts.search" } do
    it "filters by keyword" do
      Perfgate.measure { get "/microposts/search", params: { q: "rails" } }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── comments.create ───────────────────────────────────────────────────────

  describe "Comment create",
           perfgate: { id: "comments.create" } do
    it "creates a comment via POST" do
      mp = Micropost.order(:id).first!
      Perfgate.measure do
        post "/microposts/#{mp.id}/comments",
             params: { comment: { content: "benchmark comment" } }
      end
      expect(response).to redirect_to(micropost_path(mp))
    end
  end

  # ── micropost_digest.perform ──────────────────────────────────────────────

  describe "MicropostDigestJob",
           perfgate: { id: "micropost_digest.perform" } do
    it "produces a digest of recent microposts" do
      result = nil
      Perfgate.measure { result = MicropostDigestJob.new.perform(limit: 50) }
      expect(result[:count]).to be_positive
    end
  end
end
