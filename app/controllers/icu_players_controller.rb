class IcuPlayersController < ApplicationController
  load_resource except: "index"
  authorize_resource

  def index
    if params[:player_id].to_i > 0 && @player = Player.find_by_id(params[:player_id])
      # Trying to match a tournament player.
      [:last_name, :first_name].each { |name| params[name] ||= @player.send(name) }
      params[:include_duplicates] = true if @player.icu_player && @player.icu_player.master_id
    elsif params[:fide_id].to_i > 0 && @fide_player = FidePlayer.find_by_id(params[:fide_id])
      # Trying to match a FIDE player.
      [:last_name, :first_name].each { |name| params[name] ||= @fide_player.send(name) }
      params[:include_duplicates] = true if @fide_player.icu_player && @fide_player.icu_player.master_id
    end
    @icu_players = IcuPlayer.search(params, icu_players_path)
    render params[:results] ? :results : :search if request.xhr?
  end

  def show
    respond_to do |format|
      format.html
      format.js do
        @old_rating_histories = OldRatingHistory.search({ icu_player_id: params[:id], per_page: 5 }, admin_old_rating_histories_path)
        @players = Player.search({ icu_id: params[:id], per_page: 5 }, admin_players_path)
      end
    end
  end

  def graph
    @ratings_graph = IcuRatings::Graph.new(@icu_player)
    render "shared/ratings_graph/show.js"
  end
end
