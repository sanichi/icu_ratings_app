module Admin
  class PlayersController < ApplicationController
    load_resource :except => :index
    authorize_resource

    def index
      @tournament = Tournament.find(params[:tournament_id])
      @players = @tournament.players.order('num')
    end

    def show
      @tournament = @player.tournament
      if @tournament.players.size > 2
        @prev = @tournament.players.find_by_num(@player.num - 1) || @tournament.players.order("num").find(:last)
        @next = @tournament.players.find_by_num(@player.num + 1) || @tournament.players.order("num").find(:first)
      end
    end

    def edit
    end

    def update
      if @player.update_attributes(params[:player])
        @tournament = @player.tournament
      end
    end
  end
end
