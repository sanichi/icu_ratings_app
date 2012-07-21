module Admin
  class SubscriptionsController < ApplicationController
    authorize_resource

    def index
      @subs = Subscription.search(params, admin_subscriptions_path)
      render :results if request.xhr?
    end
  end
end
