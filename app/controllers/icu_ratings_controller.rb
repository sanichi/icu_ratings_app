class IcuRatingsController < ApplicationController
  def index
    @icu_ratings = IcuRating.search(params, icu_ratings_path)
    @show_original = params[:show_original] == "true"
    @show_id = params[:show_id] == "true"
    @original_ratings_article = Article.get_by_identity("original ratings")
    render :results if request.xhr?
  end

  def show
    @ratings_graph = IcuRatings::Graph.new(IcuRating.find(params[:id]))
    render "shared/ratings_graph/show.js"
  end

  def war
    @war = IcuRatings::WAR.new(params)
    render "icu_ratings/war/#{ request.xhr? ? 'results' : 'index' }"
  end

  def juniors
    @juniors = IcuRatings::Juniors.new(params)
    render "icu_ratings/juniors/#{ request.xhr? ? 'results' : 'index' }"
  end
  
  def improvers
    @improvers = IcuRatings::Improvers.new(params)
    render "icu_ratings/improvers/#{ request.xhr? ? 'results' : 'index' }"
  end
end
