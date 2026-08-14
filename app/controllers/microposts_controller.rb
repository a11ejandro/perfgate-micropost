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
    # REGRESSION: pagination removed — loads ALL comments for the micropost.
    @comments  = @micropost.comments
                           .includes(:user)
                           .oldest_first
  end

  def search
    @query      = params[:q].to_s.strip
    base        = Micropost.includes(:user).newest_first
    @microposts = if @query.present?
                    base.where("content ILIKE ?", "%#{@query}%")
                        .page(params[:page])
                        .per(PER_PAGE)
                  else
                    base.page(params[:page]).per(PER_PAGE)
                  end
    render :index
  end
end
