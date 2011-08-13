module Admin
  class LoginsController < ApplicationController
    authorize_resource

    def index
      @logins = Login.search(params, admin_logins_path)
      render :results if request.xhr?
    end
  end
end
