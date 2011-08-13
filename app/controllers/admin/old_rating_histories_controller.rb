module Admin
  class OldRatingHistoriesController < ApplicationController
    authorize_resource

    def index
      @old_rating_histories = OldRatingHistory.search(params, admin_old_rating_histories_path)
      render :player_results if request.xhr?
      @old_tournament = OldTournament.find(params[:old_tournament_id]) if params[:old_tournament_id]
      @icu_player = IcuPlayer.find(params[:icu_player_id]) if params[:icu_player_id]
    end
  end
end
