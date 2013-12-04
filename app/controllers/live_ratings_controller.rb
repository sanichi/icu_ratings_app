class LiveRatingsController < ApplicationController
  def index
    @live_ratings = LiveRating.search(params, live_ratings_path)
    @show_id = params[:show_id] == "true"
    if request.xhr?
      render :results
    end
  end
end
