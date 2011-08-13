module Admin
  class UsersController < ApplicationController
    load_resource :except => :index
    authorize_resource

    def index
      @users = User.search(params, admin_users_path)
      render :results if request.xhr?
    end

    def edit
    end

    def update
      @user.update_attributes(params[:user])
    end
    
    def show
    end
  end
end
