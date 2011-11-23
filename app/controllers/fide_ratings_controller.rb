class FideRatingsController < ApplicationController
  def index
    @fide_ratings = FideRating.search(params, fide_ratings_path)
    render :results if request.xhr?
  end
end
