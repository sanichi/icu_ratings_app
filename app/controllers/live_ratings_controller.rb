class LiveRatingsController < ApplicationController
  def index
    @live_ratings = LiveRating.search(params, live_ratings_path)
    @last_list = RatingList.last_list
    @show_id = params[:show_id] == "true"
    @show_last = params[:show_last] == "true" && @last_list
    if request.xhr?
      render :results
    end
  end
end
