class PlayersController < ApplicationController
  def show
    @player = Player.includes(results: [:opponent]).find(params[:id])
    authorize!(:show, @player)
    @tournament = @player.tournament
  end
end
