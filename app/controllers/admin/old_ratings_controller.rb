module Admin
  class OldRatingsController < ApplicationController
    authorize_resource

    def index
      @old_ratings = OldRating.search(params, admin_old_ratings_path)
      render :results if request.xhr?
    end
  end
end
