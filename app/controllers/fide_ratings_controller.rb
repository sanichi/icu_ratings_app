class FideRatingsController < ApplicationController
  def index
    @fide_ratings = FideRating.search(params, fide_ratings_path)
    render :results if request.xhr?
  end

  def show
    @ratings_graph = IcuRatings::Graph.new(FideRating.find(params[:id]))
    render "shared/ratings_graph/show.js"
  end
end
