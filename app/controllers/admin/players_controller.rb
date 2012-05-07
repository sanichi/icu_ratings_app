module Admin
  class PlayersController < ApplicationController
    load_resource except: ["index", "show", "destroy"]
    authorize_resource

    def show
      @player = Player.includes(results: [:opponent]).find(params[:id])
      @tournament = @player.tournament
      extra
    end

    def edit
    end

    def update
      update_from_id(params) unless params[:player]
      if @player.update_attributes(params[:player])
        @tournament = @player.tournament
      end
    end

    def destroy
      @player = Player.includes(results: [:opponent]).find(params[:id])
      @tournament = @player.tournament
      if @player.deletable?
        @tournament.remove(@player)
        redirect_to [:admin, @tournament], notice: "Deleted player #{@player.name}"
      else
        # Shouldn't happen because a delete button will not be provided.
        extra
        flash.now[:alert] = "Players that have at least one opponent can't be deleted"
        render "show"
      end
    end

    private

    def update_from_id(params)
      hash = ActiveSupport::HashWithIndifferentAccess.new
      keys = [:first_name, :last_name, :fed, :title, :gender]
      if params[:icu_id] && ip = IcuPlayer.find_by_id(params[:icu_id])
        hash[:icu_id] = params[:icu_id]
        keys.each { |k| v = ip.send(k); hash[k] = v if v.present? }
        hash[:dob] = ip.dob if ip.dob.present?
        hash[:fide_id] = ip.fide_player.id if ip.fide_player
      elsif params[:fide_id] && fp = FidePlayer.find_by_id(params[:fide_id])
        hash[:fide_id] = params[:fide_id]
        keys.each { |k| v = fp.send(k); hash[k] = v if v.present? }
        hash[:fide_rating] = fp.rating unless @player.fide_rating
      end
      params[:player] = hash
    end
    
    def extra
      if @tournament.players.size > 2
        # Note that player.find_by_num started going into an infinte loop here after the upgrate to rails 3.1.
        @prev = @tournament.players.where("num = ?", @player.num - 1).first || @tournament.players.order("num").last
        @next = @tournament.players.where("num = ?", @player.num + 1).first || @tournament.players.order("num").first
      end
    end
  end
end
