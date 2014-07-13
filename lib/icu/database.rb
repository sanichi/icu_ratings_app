require 'mysql2'

module ICU
  module Database
    class Pull
      SyncError = Class.new(StandardError)

      # Should be run periodically, about once per day, to keep player tables in sync.
      class Player < Pull
        def sync
          success = sync_players_steps
          Event.create(name: "ICU Player Synchronisation", report: report, time: Time.now - @start, success: success)
        end

        private

        def sync_players_steps
          begin
            get_our_players
            get_their_players
            update_ours_from_theirs
          rescue SyncError => e
            @error = e.message
            return false
          rescue => e
            @error = e.message
            e.backtrace.each { |b| @error += "\n#{b}" }
            return false
          end

          true
        end

        MAP =
        {
          :'players.id'      => :id,
          first_name:           :first_name,
          last_name:            :last_name,
          dob:                  :dob,
          joined:               :joined,
          fed:                  :fed,
          gender:               :gender,
          player_title:         :title,
          :'players.email'   => :email,
          status:               :deceased,
          player_id:            :master_id,
          :'players.address' => :address,
          home_phone:           :phone_numbers,
          work_phone:           :phone_numbers,
          mobile_phone:         :phone_numbers,
          note:                 :note,
          name:                 :club,
        }

        def update_ours_from_theirs
          @updates = []
          @creates = []
          @changes = Hash.new(0)
          @their_players.keys.each do |id|
            their_player = @their_players[id]
            our_player = @our_players[id]
            if our_player
              their_player.keys.each { |key| our_player.send("#{key}=", their_player[key])}
              if our_player.changed? && our_player.valid?
                @updates.push(id)
                our_player.changed.each { |attr| @changes[attr] += 1 }
              end
            else
              our_player = IcuPlayer.new(their_player) { |p| p.id = id }
              @creates.push(id) if our_player.valid?
            end
            raise SyncError.new("invalid player: #{our_player.inspect})") unless our_player.valid?
            our_player.save! if our_player.changed?
          end
        end

        def get_their_players
          @their_players = @client.query(players_sql).inject({}) do |players, player|
            id = player.delete(:id)
            player[:home_phone] = %w[home work mobile].map { |n| [n, player.delete("#{n}_phone".to_sym)] }.reject { |p| p[1].blank? }.map { |d| d.join(": ") }.join(", ")
            players[id] = player.keys.inject({}) do |hash, their_key|
              our_key = MAP[their_key]
              if our_key
                hash[our_key] = case our_key
                  when :deceased then player[their_key] == "deceased"
                  else player[their_key].presence
                end
              end
              hash
            end
            players
          end
        end

        # Legacy inport (www1 => www2) details:
        #   after sync:players
        #     total: 10298
        #     status: active=10130, deceased=39, inactive=129 (these are duplicates)
        #     source: import=10298
        #   after sync:status
        #     total: 10298
        #     status: active=6093, deceased=39, inactive=762, foreign=3404
        #     source: import=10298
        #   after sync:archive
        #     total: 13658
        #     status: active=6093, deceased=39, inactive=4122, foreign=3404
        #     source: import=10298, legacy=3360
        def players_sql
          # For now, sync just like the old ratings site (include duplicates and foreigners but not the archived players).
          # Eventual aim is to remove inactives and foreigners and be able to easily unarchive players by marking them as active.
          "SELECT #{MAP.keys.join(', ')} FROM players LEFT JOIN clubs ON club_id = clubs.id where source = 'import'"
        end

        def report
          str = Array.new
          str.push "creates: #{summarize_list(@creates)}"
          str.push "updates: #{summarize_list(@updates)}"
          str.push "changes: #{summarize_changes}"
          str.push "error: #{@error}" if @error
          str.join("\n")
        end
      end

      # Should be run periodically, about once per day, to keep users in sync.
      # Should be run after ICU players are synchronized, as unrecognized ICU IDs are rejected.
      class User < Pull
        def sync
          success = sync_user_steps
          Event.create(name: "ICU User Synchronisation", report: report, time: Time.now - @start, success: success)
        end

        private

        def sync_user_steps
          begin
            get_our_players
            get_our_users
            get_their_users
            update_ours_from_theirs
            stats
            report
          rescue SyncError => e
            @error = e.message
            return false
          rescue => e
            @error = e.message
            e.backtrace.each { |b| @error += "\n#{b}" }
            return false
          end

          true
        end

        MAP =
        {
          id:                 :id,
          email:              :email,
          encrypted_password: :password,
          salt:               :salt,
          player_id:          :icu_id,
          expires_on:         :expiry,
          verified_at:        :status,
        }

        def get_our_users
          @our_users = ::User.all.inject({}) { |h,u| h[u.id] = u; h }
        end

        def get_their_users
          @bad_icu_ids = []
          @bad_emails = []
          @their_users = @client.query(sql).inject({}) do |users, user|
            id = user.delete(:id)
            users[id] = user.keys.inject({}) do |hash, their_key|
              our_key = MAP[their_key]
              hash[our_key] = user[their_key].presence if our_key
              if our_key == :status
                hash[:status] = hash[:status].blank? ? "pending" : "ok" # turn verified_at into one of the legal status types
              end
              hash
            end
            icu_id = users[id][:icu_id]
            email = users[id][:email]
            unless icu_id && @our_players[icu_id]
              users.delete(id)
              @bad_icu_ids.push(icu_id || 0)
            end
            unless email && email.match(::User::EMAIL)
              users.delete(id)
              @bad_emails.push("#{id}|#{email.to_s}")
            end
            users
          end
        end

        # Legacy inport (www1 => www2) details (which deliberately dropped bad status or pending at the time performed):
        # after sync:users there were a total of 1157 users, all with status OK and verified. Prior to the migration,
        # ratings1 had a lot of pending users - these should be deleted in ratings 2 just after the sync.
        # In future we should aim to sync verified users only and introduce a 'bad' status for ratings users
        # (so www users who are temporarily banned - by having a non-OK status - are prevented from logging into ratings).
        def sql
          "SELECT #{MAP.keys.join(', ')} FROM users WHERE status = 'OK' AND player_id IS NOT NULL AND expires_on IS NOT NULL"
        end

        def update_ours_from_theirs
          @updates = []
          @creates = []
          @changes = Hash.new(0)
          @their_users.keys.each do |id|
            their_user = @their_users[id]
            our_user = @our_users[id] || ::User.new
            their_user.keys.each { |key| our_user.send("#{key}=", their_user[key]) }
            raise SyncError.new("invalid user: #{our_user.inspect})") unless our_user.valid?
            if our_user.id
              if our_user.changed?
                @updates.push(id)
                our_user.changed.each { |attr| @changes[attr] += 1 }
              end
            else
              our_user.id = id
              @creates.push(id)
            end
            our_user.save! if our_user.changed?
          end
        end

        def stats
          @ours_not_theirs = @our_users.keys.reject { |id| @their_users[id] }
          @theirs_not_ours = @their_users.keys.reject { |id| @our_users[id] }
        end

        def report
          str = Array.new
          str.push "our users: #{@our_users.size}" if @our_users
          str.push "their users: #{@their_users.size}" if @their_users
          str.push "ours but not theirs: #{summarize_list(@ours_not_theirs)}" if @ours_not_theirs
          str.push "theirs but not ours: #{summarize_list(@theirs_not_ours)}" if @theirs_not_ours
          str.push "bad emails: #{summarize_list(@bad_emails)}"
          str.push "creates: #{summarize_list(@creates)}"
          str.push "updates: #{summarize_list(@updates)}"
          str.push "changes: #{summarize_changes}"
          str.push "unrecognised ICU IDs: #{summarize_list(@bad_icu_ids)}"
          str.push "error: #{@error}" if @error
          str.join("\n")
        end
      end

      # Sync should be run about once a week, to get new ICU foreign rating fees.
      class Item < Pull
        def sync
          success = sync_item_steps
          Event.create(name: "ICU Item Synchronisation", report: report, time: Time.now - @start, success: success)
        end

        private

        def sync_item_steps
          begin
            get_our_fees
            get_their_items
            update_ours_from_theirs
          rescue SyncError => e
            @error = e.message
            return false
          rescue => e
            @error = e.message
            e.backtrace.each { |b| @error += "\n#{b}" }
            return false
          end

          true
        end

        MAP =
        {
          item_id:          :id,
          item_description: :description,
          pay_status:       :status,
          item_type:        :category,
          item_date:        :date,
          item_icu_id:      :icu_id,
        }

        def get_our_fees
          @our_fees = Fee.all.inject({}) { |h,f| h[f.id] = f; h }
        end

        def get_their_items
          @their_items = @client.query(sql).inject({}) do |items, item|
            id = item.delete(:item_id)
            items[id] = item.keys.inject({}) do |hash, their_key|
              our_key = MAP[their_key]
              hash[our_key] = item[their_key].presence if our_key
              hash
            end
            items
          end
        end

        def update_ours_from_theirs
          @updates = []
          @creates = []
          @changes = Hash.new(0)
          @their_items.keys.each do |id|
            their_item = @their_items[id]
            our_fee = @our_fees[id] || Fee.new
            their_item.keys.each { |key| our_fee.send("#{key}=", their_item[key]) }
            raise SyncError.new("invalid fee: #{our_fee.inspect})") unless our_fee.valid?
            if our_fee.id
              if our_fee.changed?
                @updates.push(id)
                our_fee.changed.each { |attr| @changes[attr] += 1 }
              end
            else
              our_fee.id = id
              @creates.push(id)
            end
            our_fee.save! if our_fee.changed?
          end
        end

        def sql
          "SELECT #{MAP.keys.join(', ')} from items, payments where item_pay_id = pay_id and pay_status != 'Created' and item_type = 'FTR'"
        end

        def report
          str = Array.new
          str.push "our fees: #{@our_fees.size}" if @our_fees
          str.push "their items: #{@their_items.size}" if @their_items
          str.push "creates: #{summarize_list(@creates)}"
          str.push "updates: #{summarize_list(@updates)}"
          str.push "changes: #{summarize_changes}"
          str.push "error: #{@error}" if @error
          str.join("\n")
        end
      end

      # Sync should be run about once a week, but more often, perhaps manually, just before a new rating list is published.
      # Treat lifetime (index 0) and paid subs (index 1) as separate, able to coexist for the same player.
      class Subs < Pull
        def sync(season=nil)
          success = sync_subs_steps(season)
          Event.create(name: "ICU Subs Synchronisation", report: report, time: Time.now - @start, success: success)
        end

        private

        def sync_subs_steps(season)
          begin
            get_season(season)
            get_our_subs
            check_our_dups
            get_their_subs
            check_their_dups
            do_creates_and_updates
            do_deletes
          rescue SyncError => e
            @error = e.message
            return false
          rescue => e
            @error = e.message
            e.backtrace.each { |b| @error += "\n#{b}" }
            return false
          end

          true
        end

        def get_season(season)
          if season
            match = season.match(/\A20(\d\d)-(\d\d)\Z/)
            raise SyncError.new("invalid season: #{season}") unless match && match[1].to_i + 1 == match[2].to_i
            @season = "20#{match[1]}-#{match[2]}"
          else
            @season = Subscription.season
          end
          @season_start = "#{@season[0,4]}-09-01"
        end

        def get_our_subs
          @our_subs = Array.new(2)
          [0, 1].each do |i|
            @our_subs[i] = (i == 0 ? Subscription.where(category: "lifetime") : Subscription.where("season = ? AND category != ?", @season, "lifetime")).inject({}) do |hash, sub|
              hash[sub.icu_id] = Array.new unless hash[sub.icu_id]
              hash[sub.icu_id].push sub
              hash
            end
          end
        end

        def check_our_dups
          @our_dups = Array.new(2)
          [0, 1].each { |i| @our_dups[i] = @our_subs[i].reject{ |k,v| v.size == 1 }.keys.sort }
        end

        def get_their_subs
          @their_subs = Array.new(2)
          [0, 1].each do |i|
            cats = i == 0 ? %w(lifetime) : %w(online offline)
            @their_subs[i] = cats.inject({}) do |hash, category|
              @client.query(sql(category)).each do |sub|
                icu_id = sub[:icu_id]
                sub[:category] = category
                sub[:pay_date] = nil if i == 0
                sub[:season] = @season if i == 1
                hash[icu_id] = Array.new unless hash[icu_id]
                hash[icu_id].push(sub)
              end
              hash
            end
          end
        end

        def check_their_dups
          @their_dups = Array.new(2)
          [0, 1].each { |i| @their_dups[i] = @their_subs[i].reject{ |k,v| v.size == 1 }.keys.sort }
        end

        def do_creates_and_updates
          pref = Hash.new(3)
          pref["online"] = 1
          pref["offline"] = 2
          @creates = Array.new(2){[]}
          @updates = Array.new(2){[]}
          @thesame = Array.new(2){[]}
          [0, 1].each do |i|
            @their_subs[i].each do |icu_id, subs|
              subs.sort! { |a, b| pref[a[:category]] <=> pref[b[:category]] } if subs.size > 1
              tsub = subs.first
              if @our_subs[i][icu_id]
                raise SyncError.new("our #{i == 0 ? 'lifetime' : 'paid'} subs contain a duplicate for #{icu_id}") unless @our_subs[i][icu_id].size == 1
                osub = @our_subs[i][icu_id].first
                if osub.category == tsub[:category]
                  @thesame[i].push(icu_id)
                else
                  puts "#{i}|#{icu_id}|#{osub.category}|#{tsub[:category]}"
                  osub.destroy
                  Subscription.create!(tsub)
                  @updates[i].push(icu_id)
                end
              else
                Subscription.create!(tsub)
                @creates[i].push(icu_id)
              end
            end
          end
        end

        def do_deletes
          @deletes = Array.new(2, [])
          [0, 1].each do |i|
            @our_subs[i].each do |icu_id, subs|
              unless @their_subs[i][icu_id]
                @our_subs[i][icu_id].each { |sub| sub.destroy }
                @deletes[i].push(icu_id)
              end
            end
          end
        end

        def report
          str = Array.new
          str.push "season: #{@season}" if @season
          [0, 1].each do |i|
            type = i == 0 ? "lifetime" : "paid"
            str.push "our #{type} subs: #{@our_subs[i].size}" if @our_subs
            str.push "our #{type} dups: #{summarize_list(@our_dups[i])}" if @our_dups
            str.push "their #{type} subs: #{@their_subs[i].size}" if @their_subs
            str.push "their #{type} dups: #{summarize_list(@their_dups[i])}" if @their_dups
            str.push "#{type} creates: #{summarize_list(@creates[i])}" if @creates
            str.push "#{type} updates: #{summarize_list(@updates[i])}" if @updates
            str.push "#{type} unchanged: #{summarize_list(@thesame[i])}" if @thesame
            str.push "#{type} deletes: #{summarize_list(@deletes[i])}" if @deletes
          end
          str.push "error: #{@error}" if @error
          str.join("\n")
        end

        def sql(category)
          "SELECT player_id AS icu_id, date(created_at) AS pay_date from items WHERE type = 'Item::Subscription' AND status = 'paid'" + case category
            when "online"  then " AND start_date = '#{@season_start}' AND payment_method IN ('paypal', 'stripe')"
            when "offline" then " AND start_date = '#{@season_start}' AND payment_method IN ('cheque', 'cash')"
            else                " AND start_date IS NULL"
          end
        end
      end

      # This is for checking stuff when a user has difficulty loggining in.
      def get_member(id, email)
        ms = @client.query("SELECT mem_email, mem_status, mem_password, mem_salt, mem_expiry FROM members WHERE mem_id = #{id}")
        return "couldn't find member with ID #{id}" if ms.size == 0
        return "found more than one (#{ms.size}) members with ID #{id}" if ms.size > 1
        m = ms.first
        address, password, salt, status, expiry = [:mem_email, :mem_password, :mem_salt, :mem_status, :mem_expiry].map { |k| m[k] }
        return "expected email '#{email}' but got '#{address}'"                        unless email == address
        return "expected status in (#{::User::STATUS.join(', ')}) but got '#{status}'" unless ::User::STATUS.include?(status)
        return "expected password but got nothing"                                     unless password
        return "expected 32 character password but got #{password.length}"             unless password.length == 32
        return "expected salt but got nothing"                                         unless salt
        return "expected 32 character salt but got #{salt.length}"                     unless salt.length == 32
        { password: password, salt: salt, status: status, expiry: expiry }
      rescue Mysql2::Error => e
        return "mysql error: #{e.message}"
      rescue => e
        return "error: #{e.message}"
      end

      private

      def initialize
        @client = Mysql2::Client.new(Rails.application.secrets.www_db.symbolize_keys)
        @client.query_options.merge!(symbolize_keys: true)
        @start = Time.now
      end

      def get_our_players
        @our_players = IcuPlayer.all.inject({}) { |h,m| h[m.id] = m; h }
      end

      def summarize_list(list)
        return "none" if list.nil? || list.size == 0
        list.sort!
        str = Array.new
        str.push "#{list.size}:"
        if list.size > 6
          str.push list[0, 5].join(", ")
          str.push "..."
          str.push list.last
        else
          str.push list.join(", ")
        end
        str.join(" ")
      end

      def summarize_changes
        return "none" if @changes.nil? || @changes.keys.size == 0
        @changes.keys.sort.map { |key| "#{key}: #{@changes[key]}" }.join(", ")
      end
    end

    class Push
      def initialize
        @client = Mysql2::Client.new(Rails.application.secrets.www_db.symbolize_keys)
        @client.query_options.merge!(symbolize_keys: true)
      end

      def update_member(id, email, pass, salt, status)
        return unless status || (pass && salt)
        return "attempt to set invalid password '#{pass}'" if pass && pass.length != 32
        return "attempt to set invalid salt '#{salt}'"     if salt && salt.length != 32
        return "attempt to set invalid status '#{status}'" if status && !::User::STATUS.include?(status)
        ms = @client.query("SELECT mem_email, mem_status, mem_password, mem_salt FROM members WHERE mem_id = #{id}")
        return "couldn't find member with ID #{id}" if ms.size == 0
        return "found more than one (#{ms.size}) members with ID #{id}" if ms.size > 1
        m = ms.first
        return "expected email #{email} but got '#{m[:mem_email]}'" unless email == m[:mem_email]
        return "can't update member record with status '#{m[:mem_status]}'" unless ::User::STATUS.include?(m[:mem_status])
        updates = []
        updates.push "mem_password = '#{pass}'" if pass && pass != m[:mem_password]
        updates.push "mem_salt = '#{salt}'"     if salt && salt != m[:mem_salt]
        if status && status != m[:mem_status]
          updates.push "mem_status = '#{status}'"
          updates.push "mem_verified = %s" % (status == "ok" ? "'#{Time.now.to_s(:db)}'" : "NULL")
        end
        @client.query("UPDATE members SET #{updates.join(', ')} WHERE mem_id = #{id}") unless updates.empty?
        nil
      rescue Mysql2::Error => e
        return "mysql error: #{e.message}"
      rescue => e
        return "error: #{e.message}"
      end
    end
  end
end
