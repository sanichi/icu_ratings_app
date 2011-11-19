class IcuRatingsController < ApplicationController
  def index
    @icu_ratings = IcuRating.search(params, icu_ratings_path)
    render :results if request.xhr?
  end
end
