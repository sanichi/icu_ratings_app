class TournamentsController < ApplicationController
  def index
    params[:admin] = false
    @tournaments = Tournament.search(params, tournaments_path)
    render :results if request.xhr?
  end

  def show
    if params[:notes]
      @tournament = Tournament.find(params[:id])
      render "admin/tournaments/notes/show"
    else
      @tournament = Tournament.includes(players: [:results]).find(params[:id])
      @rankable = @tournament.rankable
      @players = @tournament.ordered_players
    end
  end
end
