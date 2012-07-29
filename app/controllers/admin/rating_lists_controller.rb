module Admin
  class RatingListsController < ApplicationController
    authorize_resource

    def index
      RatingList.auto_populate
      @rating_lists = RatingList.search(params, admin_rating_lists_path)
      render :results if request.xhr?
    end

    def show
      @rating_list = RatingList.find(params[:id])
    end
  end
end
