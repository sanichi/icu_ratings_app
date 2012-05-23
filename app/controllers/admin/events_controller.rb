module Admin
  class EventsController < ApplicationController
    load_resource except: "index"
    authorize_resource

    def index
      @events = Event.search(params, admin_events_path)
      render :results if request.xhr?
    end

    def show
    end

    def destroy
      @event.destroy
      redirect_to admin_events_path
    end
  end
end
