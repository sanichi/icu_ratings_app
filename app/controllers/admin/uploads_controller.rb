module Admin
  class UploadsController < ApplicationController
    def index
      @uploads = Upload.search(params, admin_uploads_path)
      authorize!(:index, Upload)
      render :results if request.xhr?
    end

    def show
      @upload = Upload.find(params[:id])
      authorize!(:show, @upload)
    end

    def new
      @upload = Upload.new(format: Upload::DEFAULT_FORMAT)
      authorize!(:new, @upload)
    end

    def create
      @upload = Upload.new(params[:upload])
      @upload.user = current_user
      authorize!(:create, @upload)
      @tournament = @upload.extract(params, session[:user_id])
      if @upload.save
        if @tournament
          if @tournament.save
            @tournament.renumber_opponents
            redirect_to [:admin, @tournament], notice: "New tournament created"
          else
            @upload.update_attribute :error, @tournament.error_summary
            redirect_to [:admin, @upload], alert: "Invalid tournament"
          end
        else
          redirect_to [:admin, @upload], alert: "Cannot extract tournament from file"
        end
      else
        render action: "new"
      end
    end
    
    def destroy
      @upload = Upload.find(params[:id])
      authorize!(:destroy, @upload)
      if @upload.tournament.present?
        redirect_to [:admin, @upload], alert: "You can't delete an upload which is associated with tournament"
      else
        @upload.destroy
        redirect_to new_admin_upload_path
      end
    end
  end
end
