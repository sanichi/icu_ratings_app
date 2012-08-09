module Admin
  class RatingListsController < ApplicationController
    authorize_resource

    def index
      RatingList.auto_populate
      @rating_lists = RatingList.search(params, admin_rating_lists_path)
      render :results if request.xhr?
    end

    def show
      @rating_list = RatingList.includes(:publications).find(params[:id])
      @publications = @rating_list.publications
    end

    def edit
      @rating_list = RatingList.find(params[:id])
    end

    def update
      @rating_list = RatingList.find(params[:id])
      @rating_list.update_attributes(params[:rating_list])
    end
  end
end
