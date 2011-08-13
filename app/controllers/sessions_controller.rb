class SessionsController < ApplicationController
  def new
  end

  def create
    begin
      user = User.authenticate!(params[:email], params[:password], request.ip)
      session[:user_id] = user.id
      redirect_to root_url, :notice => "Logged in as #{user.name(false)}"
    rescue => e
      flash.now.alert = e.message
      render "new"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to log_in_url, :notice => "Logged out!"
  end
end
