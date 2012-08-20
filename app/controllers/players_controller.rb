class PlayersController < ApplicationController
  def show
    @player = Player.includes(results: [:opponent]).find(params[:id])
    authorize!(:show, @player)
    @tournament = @player.tournament
    @bonus_article = Article.get_by_identity("bonus points")
  end
end
