class CommentsController < ApplicationController
  def create
    @micropost = Micropost.find(params[:micropost_id])
    # Pick a deterministic user for test/demo purposes (no auth in MVP).
    user = User.order(:id).first

    @comment = @micropost.comments.build(
      content: comment_params[:content],
      user:    user
    )

    if @comment.save
      redirect_to @micropost, notice: "Comment added."
    else
      redirect_to @micropost, alert: @comment.errors.full_messages.to_sentence
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:content)
  end
end
