class FidePlayersController < ApplicationController
  load_resource :except => :index
  authorize_resource

  def index
    if params[:player_id].to_i > 0
      @player = Player.find(params[:player_id])
      [:last_name, :first_name].each { |name| params[name] ||= @player.send(name) } if @player
    end
    @fide_players = FidePlayer.search(params, fide_players_path)
    render params[:results] ? :results : :search if request.xhr?
  end

  def show
  end
end
