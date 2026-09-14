require "rails_helper"

RSpec.describe "Microposts", type: :request do
  let!(:users)      { create_list(:user, 3) }
  let!(:microposts) { users.flat_map { |u| create_list(:micropost, 5, user: u) } }

  describe "GET /microposts" do
    it "returns 200 and lists microposts" do
      get microposts_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(microposts.first.content.truncate(80))
    end
  end

  describe "GET /microposts/:id" do
    let(:mp) { microposts.first }

    it "returns 200 and shows the micropost" do
      get micropost_path(mp)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(mp.content)
    end

    it "shows comment authors" do
      create_list(:comment, 5, micropost: mp, user: users.first)
      get micropost_path(mp)

      expect(response.body).to include(users.first.name)
    end
  end

  describe "GET /microposts/search" do
    it "returns 200" do
      get search_microposts_path, params: { q: "rails" }
      expect(response).to have_http_status(:ok)
    end

    it "filters results by query" do
      create(:micropost, user: users.first, content: "unique_xyz_term here")
      get search_microposts_path, params: { q: "unique_xyz_term" }
      expect(response.body).to include("unique_xyz_term")
    end
  end

  describe "POST /microposts/:micropost_id/comments" do
    let(:mp) { microposts.first }

    it "creates a comment and redirects" do
      expect {
        post micropost_comments_path(mp), params: { comment: { content: "Nice!" } }
      }.to change(Comment, :count).by(1)
      expect(response).to redirect_to(mp)
    end

    it "increments comments_count" do
      post micropost_comments_path(mp), params: { comment: { content: "Nice!" } }
      expect(mp.reload.comments_count).to eq(1)
    end
  end
end
