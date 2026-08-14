require "rails_helper"

# Baseline workload specs.
#
# Each example is tagged `baseline: { id: "..." }` which both marks it for
# Baseline discovery AND sets a stable workload ID independent of description
# text changes.
#
# Setup runs OUTSIDE Baseline.measure; assertions run OUTSIDE the measured block.
#
# Run with:
#   RAILS_ENV=test BASELINE_DATASET_VERSION=micropost-v1 \
#     bundle exec baseline run --output .baseline/current

RSpec.describe "Baseline workloads", type: :request do
  before(:all) { WorkloadFixtures.setup }

  # ── microposts.index ──────────────────────────────────────────────────────

  describe "Micropost index",
           baseline: { id: "microposts.index" } do
    it "renders the first page" do
      Baseline.measure { get "/microposts" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── microposts.show ───────────────────────────────────────────────────────

  describe "Micropost show",
           baseline: { id: "microposts.show" } do
    it "renders a micropost with comments" do
      mp = Micropost.includes(:comments).order(:id).first!
      Baseline.measure { get "/microposts/#{mp.id}" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── microposts.search ─────────────────────────────────────────────────────

  describe "Micropost search",
           baseline: { id: "microposts.search" } do
    it "filters by keyword" do
      Baseline.measure { get "/microposts/search", params: { q: "rails" } }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── comments.create ───────────────────────────────────────────────────────

  describe "Comment create",
           baseline: { id: "comments.create" } do
    it "creates a comment via POST" do
      mp = Micropost.order(:id).first!
      Baseline.measure do
        post "/microposts/#{mp.id}/comments",
             params: { comment: { content: "benchmark comment" } }
      end
      expect(response).to redirect_to(micropost_path(mp))
    end
  end

  # ── micropost_digest.perform ──────────────────────────────────────────────

  describe "MicropostDigestJob",
           baseline: { id: "micropost_digest.perform" } do
    it "produces a digest of recent microposts" do
      result = nil
      Baseline.measure { result = MicropostDigestJob.new.perform(limit: 50) }
      expect(result[:count]).to be_positive
    end
  end
end
