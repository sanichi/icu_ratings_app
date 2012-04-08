module Admin
  class PlayersController < ApplicationController
    load_resource except: ["index", "show"]
    authorize_resource

    def show
      @player = Player.includes(results: [:opponent]).find(params[:id])
      @tournament = @player.tournament
      if @tournament.players.size > 2
        # Note that player.find_by_num started going into an infinte loop here after the upgrate to rails 3.1.
        @prev = @tournament.players.where("num = ?", @player.num - 1).first || @tournament.players.order("num").last
        @next = @tournament.players.where("num = ?", @player.num + 1).first || @tournament.players.order("num").first
      end
    end

    def edit
    end

    def update
      update_from_id(params) unless params[:player]
      if @player.update_attributes(params[:player])
        @tournament = @player.tournament
      end
    end

    private

    def update_from_id(params)
      player = ActiveSupport::HashWithIndifferentAccess.new
      if params[:icu_id] && ip = IcuPlayer.find_by_id(params[:icu_id])
        player[:icu_id]     = params[:icu_id]
        player[:first_name] = ip.first_name
        player[:last_name]  = ip.last_name
        player[:fed]        = ip.fed
        player[:title]      = ip.title
        player[:gender]     = ip.gender
        player[:dob]        = ip.dob
      elsif params[:fide_id] && fp = FidePlayer.find_by_id(params[:fide_id])
        player[:fide_id]     = params[:fide_id]
        player[:first_name]  = fp.first_name
        player[:last_name]   = fp.last_name
        player[:fed]         = fp.fed
        player[:title]       = fp.title
        player[:gender]      = fp.gender
        player[:fide_rating] = fp.rating unless @player.fide_rating
      end
      params[:player] = player
    end
  end
end
