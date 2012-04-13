module Pages
  class Overview
    def reporters
      return @r if @r
      reporters = {}

      # First, tournaments with users.
      Tournament.includes(:user).all.each do |t|
        hash = reporters[t.user_id]
        unless hash
          hash = { user: t.user, total: 0, status: { "ok" => 0, "problems" => 0 } }
          hash[:stage] = Tournament::STAGE.inject({}) { |h,s| h[s] = 0; h }
          reporters[t.user_id] = hash
        end
        hash[:total] += 1
        hash[:stage][t.stage] += 1
        hash[:status][t.status == "ok" ? "ok" : "problems"] += 1
      end

      # Second, reporters without tournaments.
      User.where("users.role = 'reporter'").joins('LEFT OUTER JOIN tournaments ON users.id = tournaments.user_id').where("tournaments.user_id IS NULL").each do |u|
        hash = { user: u, total: 0, status: { "ok" => 0, "problems" => 0 } }
        hash[:stage] = Tournament::STAGE.inject({}) { |h,s| h[s] = 0; h }
        reporters[u.id] = hash
      end

      @r = reporters.values.sort { |a,b| [b[:total], a[:user].name] <=> [a[:total], b[:user].name] }
    end

    def queued
      return @q if @q
      @q = {}
      @q["Queued"] = { icon: "ok", count: Tournament.where("rorder IS NOT NULL").count }
      @q["Rated"] = { icon: "ok", count: Tournament.where(stage: "rated").count }
      @q["Locked"] = { icon: "ok", count: Tournament.where(locked: true).count }
      @q["First"] = { icon: "ok", rorder: Tournament.minimum(:rorder)}
      @q["Next"] = { icon: "ok"}
      @q["Last"] = { icon: "ok", rorder: Tournament.maximum(:rorder)}
      @q["Rated"][:icon] = "problems" unless @q["Rated"][:count] == @q["Queued"][:count]
      @q["Locked"][:icon] = "problems" unless @q["Rated"][:count] == @q["Locked"][:count]
      @q["First"][:icon] = "problems" unless !@q["First"][:rorder] || @q["First"][:rorder] == 1
      @q["Last"][:icon] = "problems" unless !@q["Last"][:rorder] || @q["Last"][:rorder] == @q["Queued"][:count]
      @q["First"][:tournament] = Tournament.where(rorder: @q["First"][:rorder]).first if @q["First"][:rorder]
      @q["Last"][:tournament] = Tournament.where(rorder: @q["Last"][:rorder]).first if @q["Last"][:rorder]
      @q["Next"][:tournament] = Tournament.next_for_rating
      @q["Next"][:rorder] = @q["Next"][:tournament].rorder if @q["Next"][:tournament]
      @q["Next"][:icon] = "problems" if @q["Next"][:tournament]
      @q
    end

    def counts
      return @c if @c
      @c = {}
      @c["Tournaments"]  = { count: Tournament.count, path: "admin_tournaments_path" }
      @c["Users"]        = { count: User.count,       path: "admin_users_path"       }
      @c["ICU Players"]  = { count: IcuPlayer.count,  path: "icu_players_path"       }
      @c["FIDE Players"] = { count: FidePlayer.count, path: "fide_players_path"      }
      @c
    end

    def problems
      return @p if @p
      @p = {}
      @p["Tournaments"] = { icon: "ok", count: Tournament.where("status != 'ok'").count, path: "/admin/tournaments?status=problems" }
      @p["Events"]      = { icon: "ok", count: Event.where(success: false).count,        path: "/admin/events?success=0" }
      @p["Failures"]    = { icon: "ok", count: Failure.count,                            path: "/admin/failures" }
      @p.each_key { |d| @p[d][:icon] = "problems" if @p[d][:count] > 0 }
      @p
    end
  end
end
