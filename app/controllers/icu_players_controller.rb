class IcuPlayersController < ApplicationController
  load_resource :except => :index
  authorize_resource

  def index
    if params[:player_id].to_i > 0 && @player = Player.find(params[:player_id])
      [:last_name, :first_name].each { |name| params[name] ||= @player.send(name) }
      params[:include_duplicates] = true if @player.icu_player && @player.icu_player.master_id
    end
    @icu_players = IcuPlayer.search(params, icu_players_path)
    render params[:results] ? :results : :search if request.xhr?
  end

  def show
    @old_rating_histories = OldRatingHistory.search({ :icu_player_id => params[:id], :per_page => 5 }, admin_old_rating_histories_path)
  end
end
