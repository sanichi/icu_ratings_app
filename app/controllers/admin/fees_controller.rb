module Admin
  class FeesController < ApplicationController
    authorize_resource

    def index
      params[:used] = "false" if params[:used].nil?
      @fees = Fee.search(params, admin_fees_path)
      render :results if request.xhr?
    end

    def update
      @fee = Fee.find(params[:id])
      @fee.used = !@fee.used
      @fee.save!
    end
  end
end
