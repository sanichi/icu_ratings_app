module Admin
  class TournamentsController < ApplicationController
    load_resource except: ["index", "show", "update"]
    authorize_resource

    def index
      params[:admin] = true
      @tournaments = Tournament.search(params, admin_tournaments_path)
      @next_for_rating = Tournament.next_for_rating
      render view(:results, :search) if request.xhr?
    end

    def show
      @tournament = Tournament.includes(players: [:results]).find(params[:id])
      respond_to do |format|
        format.html do
          @players = @tournament.players
          @tournament.check_for_changes
          extras
        end
        format.text { render text: @tournament.export(params) }
        format.js   { render view(:options, :export) }
      end
    end

    def edit
      render view(:edit, %w{ranks reporter stage tie_breaks}.find { |g| params[g] })
    end

    def update
      @tournament = Tournament.includes(players: [:results]).find(params[:id])
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
      when params[:rate]
        error = @tournament.rate
        if error
          render "shared/alert", locals: { message: "RATING FAILED: #{error}" }
        else
          render view(:update)
        end
      when params[:locked]
        @tournament.update_column(:locked, params[:locked] == "false" ? false : true)
        render view(:update, :locked)
      when params[:tournament][:tie_breaks]
        @tournament.update_attributes(params[:tournament])
        render view(:update, :tie_breaks)
      when params[:tournament][:stage]
        @tournament.move_stage(params[:tournament][:stage], current_user)
        render view(:update)
      else
        @tournament.update_attributes(params[:tournament])
        render view(:update)
      end
      extras
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

    def view(file, group=nil)
      extras if !group && file == :update
      group ? "admin/tournaments/#{group}/#{file}" : file
    end

    def extras
      @next_for_rating = Tournament.next_for_rating
      @rordered = Tournament.where("rorder is NOT NULL").count
    end
  end
end
