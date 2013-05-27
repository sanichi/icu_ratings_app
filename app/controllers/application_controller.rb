class ApplicationController < ActionController::Base
  include SessionsHelper
  before_filter :mini_profiler

  protect_from_forgery

  rescue_from CanCan::AccessDenied do |exception|
    if request.xhr?
      render "shared/alert", locals: { message: exception.message }
    else
      redirect_to log_in_path, alert: exception.message
    end
  end
  
  private
  
  def mini_profiler
    Rack::MiniProfiler.authorize_request if current_user && current_user.role?("admin")
  end
end
