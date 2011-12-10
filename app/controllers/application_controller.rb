class ApplicationController < ActionController::Base
  include SessionsHelper

  protect_from_forgery

  rescue_from CanCan::AccessDenied do |exception|
    if request.xhr?
      render "shared/alert", message: exception.message
    else
      redirect_to log_in_path, alert: exception.message
    end
  end
end
