class PlayersController < ApplicationController
  def show
    @player = Player.includes(results: [:opponent]).find(params[:id])
    authorize!(:show, @player)
    @tournament = @player.tournament
    @bonus_article = Article.find_by_headline_and_published("Bonus Rating Points", true)
  end
end
