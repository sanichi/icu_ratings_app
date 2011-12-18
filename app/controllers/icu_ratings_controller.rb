class IcuRatingsController < ApplicationController
  def index
    @icu_ratings = IcuRating.search(params, icu_ratings_path)
    render :results if request.xhr?
  end

  def show
    @ratings_graph = RatingsGraph.new(IcuRating.find(params[:id]))
    render "shared/ratings_graph/show.js"
  end

  def war
    @war = WAR.new(params)
    render "icu_ratings/war/#{ request.xhr? ? 'results' : 'index' }"
  end

  def juniors
    @juniors = Juniors.new(params)
    render "icu_ratings/juniors/#{ request.xhr? ? 'results' : 'index' }"
  end
end
