require 'mysql2'

module ICU
  class Database
    SyncError = Class.new(StandardError)

    # Sync should be run periodically, about once per day, to keep player tables in sync.
    class Player < Database
      def sync
        success = sync_players_steps
        Event.create(name: 'ICU Player Synchronisation', report: report, time: Time.now - @start, success: success)
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
        plr_id:           :id,
        plr_first_name:   :first_name,
        plr_last_name:    :last_name,
        plr_date_born:    :dob,
        plr_date_joined:  :joined,
        plr_fed:          :fed,
        plr_sex:          :gender,
        plr_title:        :title,
        plr_email:        :email,
        plr_deceased:     :deceased,
        plr_id_dup:       :master_id,
        plr_address1:     :address,
        plr_address2:     :address,
        plr_address3:     :address,
        plr_address4:     :address,
        plr_phone_home:   :phone_numbers,
        plr_phone_work:   :phone_numbers,
        plr_phone_mobile: :phone_numbers,
        plr_note:         :note,
        club_name:        :club,
      }

      def update_ours_from_theirs
        @updates = []
        @creates = []
        @invalid = []
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
        x1950 = Date.new(1950, 1, 1)
        x1975 = Date.new(1975, 1, 1)
        @their_players = @client.query(players_sql).inject({}) do |players, player|
          id = player.delete(:plr_id)
          player[:plr_address1] = (1..4).map { |i| player.delete("plr_address#{i}".to_sym) }.reject { |a| a.blank? }.join(", ")
          player[:plr_phone_home] = %w[home work mobile].map { |n| [n, player.delete("plr_phone_#{n}".to_sym)] }.reject { |p| p[1].blank? }.map { |d| d.join(": ") }.join(", ")
          players[id] = player.keys.inject({}) do |hash, their_key|
            our_key = MAP[their_key]
            if our_key
              hash[our_key] = case our_key
                when :deceased      then player[their_key] == 'Yes'
                when :dob           then player[their_key] == x1950 ? nil : player[their_key].presence
                when :joined        then player[their_key] == x1975 ? nil : player[their_key].presence
                else player[their_key].presence
              end
            end
            hash
          end
          players
        end
      end

      def players_sql
        "SELECT #{MAP.keys.join(', ')} FROM icu_players LEFT JOIN clubs ON plr_club_id = club_id"
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

    # Should be run periodically, about once per day, to keep members/users in sync.
    # Should be run after ICU players are synchronized, as unrecognized ICU IDs are rejected.
    class Member < Database
      def sync
        success = sync_user_steps
        Event.create(name: 'ICU User Synchronisation', report: report, time: Time.now - @start, success: success)
      end

      private

      def sync_user_steps
        begin
          get_our_players
          get_our_users
          get_their_members
          update_ours_from_theirs
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
        mem_id:       :id,
        mem_email:    :email,
        mem_password: :password,
        mem_salt:     :salt,
        mem_icu_id:   :icu_id,
        mem_expiry:   :expiry,
      }

      def get_our_users
        @our_users = User.all.inject({}) { |h,u| h[u.id] = u; h }
      end

      def get_their_members
        @bad_icu_ids = []
        @their_members = @client.query(sql).inject({}) do |members, member|
          id = member.delete(:mem_id)
          members[id] = member.keys.inject({}) do |hash, their_key|
            our_key = MAP[their_key]
            hash[our_key] = member[their_key].presence if our_key
            hash
          end
          icu_id = members[id][:icu_id]
          unless icu_id && @our_players[icu_id]
            members.delete(id)
            @bad_icu_ids.push(icu_id || 0)
          end
          members
        end
      end

      def sql
        "SELECT #{MAP.keys.join(', ')} FROM members WHERE mem_status = 'ok' AND mem_icu_id IS NOT NULL AND mem_expiry IS NOT NULL"
      end

      def update_ours_from_theirs
        @updates = []
        @creates = []
        @invalid = []
        @changes = Hash.new(0)
        @their_members.keys.each do |id|
          their_member = @their_members[id]
          our_user = @our_users[id] || User.new
          their_member.keys.each { |key| our_user.send("#{key}=", their_member[key]) }
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

      def report
        str = Array.new
        str.push "users: #{@our_users.size}" if @our_users
        str.push "members: #{@their_members.size}" if @their_members
        str.push "creates: #{summarize_list(@creates)}"
        str.push "updates: #{summarize_list(@updates)}"
        str.push "changes: #{summarize_changes}"
        str.push "unrecognised ICU IDs: #{summarize_list(@bad_icu_ids)}"
        str.push "error: #{@error}" if @error
        str.join("\n")
      end
    end

    # Sync should be run just once, to get historical FIDE rating data for Irish players.
    class FIDE < Database
      def sync
        success = sync_fide_steps
        Event.create(name: 'ICU-FIDE Synchronisation', report: report, time: Time.now - @start, success: success)
      end

      private

      def sync_fide_steps
        begin
          get_our_players
          get_our_fide_players
          get_their_fide_icu_map
          update_fide_players_from_map
          get_their_fide_ratings
          update_fide_ratings
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

      def update_fide_players_from_map
        @updates  = []
        @bad_fide_ids = []
        @bad_icu_ids  = []
        @map.each_pair do |fide_id, icu_id|
          fide_player = @fide_players[fide_id]
          if fide_player
            if icu_id
              if @our_players[icu_id]
                if fide_player.icu_id != icu_id
                  fide_player.icu_id = icu_id
                  fide_player.save!
                  @updates.push(icu_id)
                end
              else
                @bad_icu_ids.push(icu_id)
              end
            end
          else
            @bad_fide_ids.push(fide_id)
          end
        end
      end

      def update_fide_ratings
        @rat_updates = 0
        @fide_ratings.each_pair do |fide_id, theirs|
          fide_player = @fide_players[fide_id]
          if fide_player
            theirs.each_pair do |list, data|
              rating, games = data
              fide_rating = fide_player.fide_ratings.detect { |fr| fr.list == list }
              if fide_rating
                fide_rating.rating = rating
                fide_rating.games = games
              else
                fide_rating = fide_player.fide_ratings.build(list: list, rating: rating, games: games)
              end
              if fide_rating.changed?
                fide_rating.save!
                @rat_updates += 1
              end
            end
          end
        end
      end

      def get_their_fide_icu_map
        @map = @client.query("SELECT fide_id, fide_icu_id FROM fide_players").inject({}) do |map, pair|
          map[pair[:fide_id]] = pair[:fide_icu_id] unless pair[:fide_id].nil?
          map
        end
      end

      def get_their_fide_ratings
        @num_fide_ratings = 0
        @fide_ratings = @client.query("SELECT fr_fide_id, fr_date, fr_rating, fr_games FROM fide_ratings").inject({}) do |map, data|
          fide_id = data[:fr_fide_id]
          list = Date.parse("#{data[:fr_date]}-01")
          rating = data[:fr_rating]
          games = data[:fr_games]
          map[fide_id] ||= Hash.new
          map[fide_id][list] = [rating, games]
          @num_fide_ratings += 1
          map
        end
      end

      def get_our_fide_players
        @fide_players = FidePlayer.all(include: :fide_ratings).inject({}) { |h,p| h[p.id] = p; h }
      end

      def report
        str = Array.new
        str.push "total FIDE IDs from ICU DB: #{@map.size}"
        str.push "FIDE IDs mapped to ICU IDs: #{@map.values.select{ |id| id }.size}"
        str.push "updates: #{summarize_list(@updates)}"
        str.push "unrecognised FIDE IDs: #{summarize_list(@bad_fide_ids)}"
        str.push "unrecognised ICU IDs: #{summarize_list(@bad_icu_ids)}"
        str.push "ICU FIDE ratings: #{@num_fide_ratings}" if @num_fide_ratings
        str.push "rating updates: #{@rat_updates}" if @rat_updates
        str.push "error: #{@error}" if @error
        str.join("\n")
      end
    end

    private

    def initialize
      @client = Mysql2::Client.new(APP_CONFIG["icu_db"].symbolize_keys)
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
end
