module Admin
  class TournamentsController < ApplicationController
    load_resource :except => :index
    authorize_resource

    def index
      @tournaments = Tournament.search(params, admin_tournaments_path)
      render :results if request.xhr?
    end

    def show
      respond_to do |format|
        format.html { @players = @tournament.players.includes(:results) }
        format.text { render :text => @tournament.export(params) }
        format.js   { render :export }
      end
    end

    def edit
      render case
      when params[:tie_breaks]
        :edit_tie_breaks
      when params[:ranks]
        :edit_ranks
      else
        :edit
      end
    end

    def update
      if params[:ranks]
        # Updating player ranks.
        @tournament.rank if params[:rank]
        @ranking = @tournament.ranking_summary
        @problem, order = false, :num
        if params[:order]
          @problem = !@ranking[:rankable]
          order = :rank unless @problem
        end
        @players = @tournament.players.order(order).includes(:results)
        render :update_ranks
      else
        # Updating (a) general tournament attributes or (b) tie break rules.
        @tournament.update_attributes(params[:tournament])
        render params[:tournament][:tie_breaks] ? :update_tie_breaks : :update
      end
    end
  end
end
