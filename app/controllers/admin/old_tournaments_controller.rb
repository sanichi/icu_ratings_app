module Admin
  class OldTournamentsController < ApplicationController
    authorize_resource

    def index
      @old_tournaments = OldTournament.search(params, admin_old_tournaments_path)
      render :results if request.xhr?
    end
  end
end
