class TournamentsController < ApplicationController
  def index
    params[:admin] = false
    @tournaments = Tournament.search(params, tournaments_path)
    render :results if request.xhr?
  end

  def show
    respond_to do |format|
      format.html do
        @tournament = Tournament.includes(players: [:results]).find(params[:id])
        @rankable = @tournament.rankable
        @players = @tournament.ordered_players
        render "show"
      end
      format.js do
        @tournament = Tournament.find(params[:id])
        render "show_notes"
      end
    end
  end
end
