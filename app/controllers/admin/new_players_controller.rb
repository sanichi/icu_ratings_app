module Admin
  class NewPlayersController < ApplicationController
    def index
      authorize! :manage, Player
      @new_players = Player.search_new_players(params, admin_new_players_path)
      render :results if request.xhr?
    end
  end
end
