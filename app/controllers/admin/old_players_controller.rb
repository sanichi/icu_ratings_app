module Admin
  class OldPlayersController < ApplicationController
    authorize_resource

    def index
      @old_players = OldPlayer.search(params, admin_old_players_path)
      render :results if request.xhr?
    end

    def show
      @old_player = OldPlayer.find(params[:id])
      render :show_note if request.xhr?
    end

    def edit
      @old_player = OldPlayer.find(params[:id])
    end

    def update
      @old_player = OldPlayer.find(params[:id])
      @old_player.update_attributes(old_params)
    end
    
    private
    
    def old_params
      params.require(:old_player).permit(:status, :note)
    end
  end
end
