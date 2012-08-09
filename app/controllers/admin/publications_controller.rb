module Admin
  class PublicationsController < ApplicationController
    authorize_resource

    def create
      @rating_list = RatingList.find(params[:rating_list_id])
      message = @rating_list.publish
      if message
        render "shared/alert", locals: { message: message }
      else
        @publications = @rating_list.publications
        render "admin/rating_lists/publications", formats: :js
      end
    end

    def show
      @publication = Publication.find(params[:id])
    end
  end
end
