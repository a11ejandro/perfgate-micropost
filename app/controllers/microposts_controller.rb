class MicropostsController < ApplicationController
  PER_PAGE = 20

  def index
    @microposts = Micropost.includes(:user)
                           .newest_first
                           .page(params[:page])
                           .per(PER_PAGE)
  end

  def show
    @micropost = Micropost.includes(:user).find(params[:id])
    @comments  = @micropost.comments
                           .includes(:user)
                           .oldest_first
                           .page(params[:page])
                           .per(PER_PAGE)
  end

  def search
    @query      = params[:q].to_s.strip
    base        = Micropost.includes(:user).newest_first
    @microposts = if @query.present?
                    # REGRESSION: loads all matching records into Ruby then paginates in memory,
                    # bypassing the database index and Kaminari's SQL LIMIT/OFFSET.
                    all_matches = base.where("content ILIKE ?", "%#{@query}%").to_a
                    Kaminari.paginate_array(all_matches)
                            .page(params[:page])
                            .per(PER_PAGE)
                  else
                    base.page(params[:page]).per(PER_PAGE)
                  end
    render :index
  end
end
