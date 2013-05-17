module Pages
  class Overview
    def reporters
      return @r if @r
      reporters = {}

      # First, tournaments with reporters.
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
      t1 = Tournament.first_for_rating
      t2 = Tournament.next_for_rating
      t3 = Tournament.last_for_rating
      @q = {}
      @q["Queued"]   = { icon: "ok", count: Tournament.where("rorder IS NOT NULL").count }
      @q["Rated"]    = { icon: "ok", count: Tournament.where(stage: "rated").count }
      @q["Unlocked"] = { icon: "ok", count: Tournament.where(locked: false).count }
      @q["First"]    = { icon: "ok", rorder: t1.try(:rorder) }
      @q["Next"]     = { icon: "ok", rorder: t2.try(:rorder) || "0" }
      @q["Last"]     = { icon: "ok", rorder: t3.try(:rorder) }
      @q["Rated"][:icon]    = "problems" unless  @q["Rated"][:count]    == @q["Queued"][:count]
      @q["Unlocked"][:icon] = "problems" unless  @q["Unlocked"][:count] == 0
      @q["First"][:icon]    = "problems" unless !@q["First"][:rorder] || @q["First"][:rorder] == 1
      @q["Next"][:icon]     = "problems" if t2
      @q["Last"][:icon]     = "problems" unless !@q["Last"][:rorder]  || @q["Last"][:rorder] == @q["Queued"][:count]
      @q["First"][:tournament] = t1
      @q["Next"][:tournament]  = t2
      @q["Last"][:tournament]  = t3
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
