class SessionsController < ApplicationController
  def new
  end

  def create
    begin
      user = User.authenticate!(params, request.ip, can?(:manage, User))
      session[:user_id] = user.id
      redirect_to my_home_path
    rescue => e
      flash.now.alert = e.message
      render "new"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to log_in_url, notice: "Logged out!"
  end
end
