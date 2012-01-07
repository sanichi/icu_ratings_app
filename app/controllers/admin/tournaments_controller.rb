module Admin
  class TournamentsController < ApplicationController
    load_resource except: "index"
    authorize_resource

    def index
      params[:admin] = true
      @tournaments = Tournament.search(params, admin_tournaments_path)
      render view(:results, :search) if request.xhr?
    end

    def show
      respond_to do |format|
        format.html do
          @players = @tournament.players.includes(:results)
          @tournament.check_status
        end
        format.text { render text: @tournament.export(params) }
        format.js   { render view(:options, :export) }
      end
    end

    def edit
      render view(:edit, %w{ranks reporter stage tie_breaks}.find { |g| params[g] })
    end

    def update
      case
      when params[:ranks]
        @tournament.rank if params[:rank]
        @ranking = @tournament.ranking_summary
        @problem, order = false, :num
        if params[:order]
          @problem = !@ranking[:rankable]
          order = :rank unless @problem
        end
        @players = @tournament.players.order(order).includes(:results)
        render view(:update, :ranks)
      when params[:tournament][:tie_breaks]
        @tournament.update_attributes(params[:tournament])
        render view(:update, :tie_breaks)
      when params[:tournament][:stage]
        @tournament.move_stage(params[:tournament][:stage], current_user)
        render :update
      else
        @tournament.update_attributes(params[:tournament])
        render :update
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

    private

    def view(file, group)
      group ? "admin/tournaments/#{group}/#{file}" : file
    end
  end
end
