class PlayersController < ApplicationController
  def show
    authorize!(:show, Player)
    @player = Player.includes(results: [:opponent]).find(params[:id])
    @tournament = @player.tournament
    @bonus_article = Article.get_by_identity("bonus points")
  end
end
