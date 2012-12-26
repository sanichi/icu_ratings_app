module Admin
  class TournamentsController < ApplicationController
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
          @players = @tournament.ordered_players(by_name: true)
          @tournament.check_for_changes
          extras
        end
        format.text { render text: @tournament.export(params) }
        format.js do
          case
          when params[:notes] then render view(:show, :notes)
          else render view(:options, :export)
          end
        end
      end
    end

    def edit
      @tournament = Tournament.find(params[:id])
      group = %w{ranks reporter stage tie_breaks fide fide_id notes}.find { |g| params[g] }
      @data = Tournaments::FideData.new(@tournament) if group == "fide"
      render view(:edit, group)
    end

    def update
      @tournament = Tournament.includes(players: [:results]).find(params[:id])
      case
      when params[:ranks]
        @tournament.rank if params[:rank]
        @ranking = @tournament.ranking_summary
        @problem, by_name = false, true
        if params[:order]
          @problem = !@ranking[:rankable]
          by_name = false unless @problem
        end
        @players = @tournament.ordered_players(by_name: by_name)
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
      when params[:rerate]
        @tournament.update_column(:rerate, params[:rerate] == "false" ? false : true)
        render view(:update, :rerate)
      when params[:tournament][:fide]
        @data = Tournaments::FideData.new(@tournament, true)
        render view(:update, :fide)
      when params[:tournament][:tie_breaks]
        @tournament.update_attributes(params[:tournament])
        render view(:update, :tie_breaks)
      when params[:tournament][:notes]
        @tournament.update_attributes(params[:tournament])
        render view(:update, :notes)
      when params[:tournament][:stage]
        @tournament.move_stage(params[:tournament][:stage], current_user)
        render view(:update)
      else
        @tournament.update_attributes(params[:tournament])
        render view(:update)
      end
    end

    def destroy
      @tournament = Tournament.find(params[:id])
      unless @tournament.deletable?
        redirect_to [:admin, @tournament], alert: "You can't delete a tournament with status #{@tournament.status}"
      else
        @tournament.destroy
        redirect_to admin_tournaments_path
      end
    end

    private

    def view(file, group=nil)
      extras if (!group && file == :update) || group == :locked || group == :rerate
      group ? "admin/tournaments/#{group}/#{file}" : file
    end

    def extras
      @next_for_rating = Tournament.next_for_rating
      @rordered = Tournament.where("rorder is NOT NULL").count
    end
  end
end
