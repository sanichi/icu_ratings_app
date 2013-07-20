class FidePlayersController < ApplicationController
  load_resource except: "index"
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

  def update
    icu_id = params[:icu_id].to_i
    if icu_id > 0
      @fide_player.update_attributes(icu_id: icu_id) if @fide_player.icu_mismatches(icu_id) == 0
    elsif params[:icu_id] == "nil"
      @fide_player.update_attributes(icu_id: nil)
    end
  end
end
