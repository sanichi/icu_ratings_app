module Admin
  class FailuresController < ApplicationController
    load_resource except: "index"
    authorize_resource
    
    def index
      @failures = Failure.search(params, admin_failures_path)
      render :results if request.xhr?
    end
    
    def new
      raise "Simulated Failure"
    end

    def show
    end

    def destroy
      @failure.destroy
      redirect_to admin_failures_path
    end
  end
end
