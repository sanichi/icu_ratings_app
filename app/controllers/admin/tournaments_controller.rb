module Admin
  class TournamentsController < ApplicationController
    load_resource except: "index"
    authorize_resource

    def index
      params[:admin] = true
      @tournaments = Tournament.search(params, admin_tournaments_path)
      render :results if request.xhr?
    end

    def show
      respond_to do |format|
        format.html do
          @players = @tournament.players.includes(:results)
          @tournament.check_status
        end
        format.text { render text: @tournament.export(params) }
        format.js   { render :export }
      end
    end

    def edit
      render case
      when params[:tie_breaks]
        :edit_tie_breaks
      when params[:ranks]
        :edit_ranks
      when params[:reporter]
        :edit_reporter
      when params[:stage]
        :edit_stage
      else
        :edit
      end
    end

    def update
      if params[:ranks]
        # Update player ranks only.
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
        # Updating (a) general tournament attributes, (b) tie break rules or (c) tournament reporter.
        @tournament.update_attributes(params[:tournament])
        render params[:tournament][:tie_breaks] ? :update_tie_breaks : :update
      end
    end

    def destroy
      unless @tournament.deletable?
        redirect_to [:admin, @tournament], alert: "You can't delete a tournament with status #{@tournament.status}"
      else
        @tournament.destroy
        redirect_to admin_tournaments_path
      end
    end
  end
end
