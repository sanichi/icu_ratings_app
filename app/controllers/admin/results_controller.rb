module Admin
  class ResultsController < ApplicationController
    load_and_authorize_resource except: ["new", "create"]

    def new
      @player = Player.find(params[:player_id])
      @result = @player.results.build(round: params[:round].to_i)
      authorize! :new, @result
      @tournament = @player.tournament
      @opponents = @tournament.possible_opponents(@result)
    end

    def create
      @result = Article.new(result_params)
      if @result.save
        @player = @result.player
        @tournament = @player.tournament
      end
      render :update
    end

    def edit
      @player = @result.player
      @tournament = @player.tournament
      @opponents = @tournament.possible_opponents(@result)
    end

    def update
      if @result.update_results(result_params, params[:opp_result])
        @player = @result.player
        @tournament = @player.tournament
      end
    end

    private

    def result_params
      params.require(:result).permit(:round, :player_id, :opponent_id, :result, :colour, :rateable)
    end
  end
end
