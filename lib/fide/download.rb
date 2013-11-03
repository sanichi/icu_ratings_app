require "net/http"

module FIDE
  class Download
    SyncError = Class.new(StandardError)
    SyncInfo  = Class.new(StandardError)

    class Irish < Download
      def initialize
        @name = "Irish FIDE Players Synchronisation"
      end

      # Run periodically (roughly every week) to sync Irish FIDE players and ratings.
      # Since the number of Irish players is relatively small, we can afford not to
      # ignore inactive players, track historical ratings and perfom creates and updates
      # through ActiveRecord. Use bin/rake sync:irish_fide_players[F] to force a reread
      # of a file already processed.
      def sync_fide_players(force=false)
        @start = Time.now
        @time = Hash.new
        begin
          get_download_details
          check_not_downloaded unless force
          download_and_save
          read_and_parse
          update_our_players_and_ratings
          event(true)
        rescue SyncInfo => e
          @info = e.message
          event(true)
        rescue SyncError => e
          @error = e.message
          event(false)
        rescue => e
          @error = e.message
          e.backtrace.each { |b| @error += "\n#{b}" }
          event(false)
        end
      end

      private

      def read_and_parse
        # Get the data out of the ZIP file.
        zip = Zip::File.open(@zip.path)
        raise SyncError.new("zip file has no entry for #{@file}") unless zip.find_entry(@file)
        data = zip.read(@file)
        raise SyncError.new("unexpected zip data encoding (#{data.encoding.name})") unless data.encoding.name.match(/^ASCII-8BIT|US-ASCII$/)
        data.force_encoding("ISO-8859-1")
        data.encode!("UTF-8")

        # Parse the data using SAX parser based on FIDE::Download::Parser and FIDE::Download::Player.
        @their_players = Hash.new
        sax = Parser.new do |p|
          next unless p["country"] == "IRL"
          player = FIDE::Download::Player.new(p)
          @their_players[player.id] = player
        end
        parser = Nokogiri::XML::SAX::Parser.new(sax)
        begin
          parser.parse(data)
        rescue => e
          raise SyncError.new("failed to parse XML data: #{e.message}")
        end
        @time["parse"] = Time.now - @start

        # Sanity checks.
        raise SyncError.new("not enough Irish players found: #{@their_players.size}") unless @their_players.size > 200
        invalid = @their_players.values.select{ |p| p.invalid? }
        raise SyncError.new("too many invalid players (#{invalid.size}): #{invalid.examples(3)}") if invalid.size > 0
      end

      def update_our_players_and_ratings
        @our_players = FidePlayer.all.inject({}) { |h,p| h[p.id] = p; h }
        @our_ratings = FideRating.find_all_by_list(@list).inject({}) { |h,r| h[r.fide_id] = r; h }
        @updates = []
        @creates = []
        @invalid = []
        @changes = Hash.new(0)
        @their_players.keys.each do |id|
          tplr = @their_players[id].to_h
          oplr = @our_players[id]
          rating = tplr[:rating]
          games  = tplr.delete(:games)
          active = tplr.delete(:active)
          if oplr
            tplr.keys.each { |key| oplr.send("#{key}=", tplr[key]) }
            if oplr.changed?
              @updates.push(id)
              oplr.changed.each { |atr| @changes[atr] += 1 }
            end
          else
            oplr = FidePlayer.new(tplr) { |p| p.id = id }
            @creates.push(id)
          end
          if oplr.valid?
            oplr.save(validation: false) if oplr.changed?
            if rating && games
              ofr = @our_ratings[id]
              if ofr
                ofr.rating = rating
                ofr.games = games
                if ofr.valid?
                  if ofr.changed?
                    ofr.save(validation: false)
                    @changes[:rating] += 1
                  end
                else
                  @invalid.push("#{id} #{ofr.errors.inspect}")
                end
              else
                oplr.fide_ratings.create(list: @list, rating: rating, games: games)
                @changes[:rating] += 1 if @our_players[id]
              end
            end
          else
            @invalid.push("#{id} #{oplr.errors.inspect}")
          end
          raise SyncError.new("too many invalid records") if @invalid.size > 10
        end
        @time["update"] = Time.now - @start
      end

      def report
        str = Array.new
        str.push("link: #{@link}") if @link
        str.push("signature: #{@signature}") if @signature
        str.push("list: #{@list}") if @list
        str.push("info: #{@info}") if @info
        str.push "records extracted: #{@their_players.size}" if @their_players
        str.push "records existing: #{@our_players.size}" if @our_players
        str.push "invalid records: #{summarize_invalid}" if @invalid
        str.push "creates: #{summarize_list(@creates)}" if @creates
        str.push "updates: #{summarize_list(@updates)}" if @updates
        str.push "changes: #{summarize_changes}" if @changes
        str.concat summarize_time(@time) if @time.size > 0
        str.push "error: #{@error}" if @error
        str.join("\n")
      end

      def summarize_list(list)
        return "none" if list.size == 0
        list.sort!
        str = Array.new
        str.push "#{list.size}:"
        if list.size > 5
          str.push list[0, 4].join(", ")
          str.push "..."
          str.push list.last
        else
          str.push list.join(", ")
        end
        str.join(" ")
      end

      def summarize_changes
        return "none" if @changes.keys.size == 0
        @changes.keys.sort_by(&:to_s).map { |key| "#{key}: #{@changes[key]}" }.join(", ")
      end

      def summarize_invalid
        return "none" if @invalid.size == 0
        "#{@invalid.size}\n#{@invalid.join("\n")}"
      end
    end

    class Other < Download
      def initialize
        @name = "Non-Irish FIDE Players Synchronisation"
      end

      # Run periodically (roughly weekly) to sync non-Irish FIDE players and ratings.
      # Since the number of such players is large, we ignore inactive players, only track the
      # latest rating, avoid ActiveRecord and instead perform updates by creating a file and
      # loading it into MySQL. Use bin/rake sync:other_fide_players[F] to force a reread of
      # a file already processed.
      def sync_fide_players(force=false)
        @start = Time.now
        @time = Hash.new
        begin
          get_download_details
          check_not_downloaded unless force
          download_and_save
          read_parse_and_save
          load_into_mysql
          event(true)
        rescue SyncInfo => e
          @info = e.message
          event(true)
        rescue SyncError => e
          @error = e.message
          event(false)
        rescue => e
          @error = e.message
          e.backtrace.each { |b| @error += "\n#{b}" }
          event(false)
        end
      end

      def read_parse_and_save
        # Get the data out of the ZIP file.
        zip = Zip::File.open(@zip.path)
        raise SyncError.new("zip file has no entry for #{@file}") unless zip.find_entry(@file)
        data = zip.read(@file)
        raise SyncError.new("unexpected zip data encoding (#{data.encoding.name})") unless data.encoding.name.match(/^ASCII-8BIT|US-ASCII$/)
        data.force_encoding("ISO-8859-1")
        data.encode!("UTF-8")

        # Prepare to save CSV data to a file.
        @csv = "#{Rails.root}/tmp/other_fide_players.csv"
        file = File.open(@csv, "w")
        @invalid = Hash.new(0)
        @inactive = 0
        @irish = 0
        @records = 0
        @count = 0
        got_id = Hash.new
        created_at = Time.now.to_s(:db)
        updated_at = created_at
        icu_id = '\N'

        # Parse the data using SAX parser based on FIDE::Download::Parser and FIDE::Download::Player.
        sax = Parser.new do |p|
          @count+= 1
          unless p["country"] == "IRL"
            if p["flag"] && p["flag"].match(/i/)
              @inactive+= 1
            else
              player = FIDE::Download::Player.new(p)
              if got_id[player.id]
                @invalid["duplicate"]+= 1
              elsif reason = player.invalid?
                @invalid[reason]+= 1
              else
                file.write(player.to_csv(created_at, updated_at) + "\n")
                @records+= 1
                got_id[player.id] = true
              end
            end
          else
            @irish+= 1
          end
        end
        parser = Nokogiri::XML::SAX::Parser.new(sax)
        begin
          parser.parse(data)
        rescue => e
          raise SyncError.new("failed to parse XML data: #{e.message}")
        end
        file.close
        @time["parse"] = Time.now - @start

        # Sanity checks.
        raise SyncError.new("unexpectedly low total number of records: #{@count}") unless @count > 120000
        raise SyncError.new("unexpectedly low number of inactive records: #{@inactive}") unless @inactive > 40000
      end

      def load_into_mysql
        # Check the MySQL load file exists.
        raise SyncError.new("load file (#{@csv}) does not exist or is empty") unless File.size?(@csv)

        # How many original records were there?
        @records_before_load = FidePlayer.count

        # Load the file into the database using REPLACE (quicker than deleteing records first).
        ActiveRecord::Base.connection.execute("LOAD DATA INFILE '#{@csv}' REPLACE INTO TABLE fide_players FIELDS TERMINATED BY ','")
        @records_after_load = FidePlayer.count
        @time['load'] = Time.now - @start
      end

      def report
        str = Array.new
        str.push("link: #{@link}") if @link
        str.push("signature: #{@signature}") if @signature
        str.push("list: #{@list}") if @list
        str.push("info: #{@info}") if @info
        str.push("total records: #{@count}") if @count
        str.push "records used: #{@records}" if @records
        str.push "inactive players skipped: #{@inactive}" if @inactive
        str.push "Irish players skipped: #{@irish}" if @irish
        str.push "invalid records: #{summarize_invalid}" if @invalid
        str.push "records before load: #{@records_before_load}" if @records_before_load
        str.push "records after load: #{@records_after_load}" if @records_after_load
        str.concat summarize_time(@time) if @time.size > 0
        str.push "error: #{@error}" if @error
        str.join("\n")
      end

      def summarize_invalid
        return "none" if @invalid.size == 0
        @invalid.keys.sort.map{ |reason| "#{reason}: #{@invalid[reason]}" }.join(", ")
      end
    end

    private

    def request(url)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 180
      req = Net::HTTP::Get.new(uri.request_uri)
      begin
        res = http.request(req)
      rescue Timeout::Error
        raise SyncError.new("#{uri} timed out")
      end
      raise SyncError.new("unexpected response for #{uri}: #{res.code}") unless res.code == "200"
      res
    end

    def get_download_details
      res = request("http://ratings.fide.com/download.phtml")
      # <li><a href=http://ratings.fide.com/download/standard_oct12frl_xml.zip class=tur>Download October 2012 FRL</a>(XML)
      # <small>(Updated: 15 Oct 2012, Size: 3 762 108 bytes)</small><br>
      # </li>
      raise SyncError.new("no links detected") unless res.body.match(/href=["']?(http:\/\/ratings.fide.com\/download\/standard_(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)(\d\d)frl_xml\.zip)[^>]*>[^<]+<\/a>[^<]*<small>([^<]+)<\/small>/)
      @link = $1
      month = $2
      year  = $3
      note  = $4
      @file = "standard_#{month}#{year}frl_xml.xml"
      @list = check_list("1st #{month} #{year}")
      raise SyncError.new("no updated date found in note") unless note.match(/Updated:\s+(\d[\d\w\s]+\d)\s*,/i)
      updated = Date.parse($1).to_s
      raise SyncError.new("no file size found in note") unless note.match(/Size:\s+(\d[\d\s]+\d)\s+bytes/i)
      size = $1.gsub(/\s/, "")
      @signature = [@link, updated, size].join(", ")
      @time["index download"] = Time.now - @start
    end

    def check_not_downloaded
      already_done = Event.where("name = '#{@name}' AND success = 1 AND report LIKE '%signature: #{@signature}%'").order('created_at asc')
      raise SyncInfo.new("already done on #{already_done.first.created_at}") if already_done.size > 0
    end

    def download_and_save
      res = request(@link)
      raise SyncError.new("unexpected content-type (#{res.content_type})") unless res.content_type.match(/^application\/(zip|x-zip-compressed)$/)
      raise SyncError.new("unexpected zip archive encoding (#{res.body.encoding.name})") unless res.body.encoding.name.match(/^ASCII-8BIT|US-ASCII$/)
      @zip = Tempfile.new("fide_ratings.zip")
      @zip.syswrite(res.body)
      @zip.close
      @time["data download"] = Time.now - @start
    end

    def summarize_time(time)
      time.keys.map { |key| "seconds after #{key}: #{'%.1f' % time[key]}" }
    end

    def check_list(list)
      begin
        date = Date.parse(list)
      rescue
        raise SyncError.new("invalid rating list (#{list})")
      end
      today = Date.today
      diff = (today - date).to_i
      raise SyncError.new("rating list (#{list}) is in the future") if diff < 0
      raise SyncError.new("rating list (#{list}) is too far in the past") if diff > 90
      date
    end

    def event(success)
      Event.create(name: @name, report: report, time: (Time.now - @start).to_i, success: success)
    end

    class Player
      attr_reader :id, :first_name, :last_name, :fed, :born, :gender, :title, :rating, :games, :active
      NULL = '\N'

      def initialize(hash)
        self.id     = hash["fideid"]   if hash["fideid"]
        self.name   = hash["name"]     if hash["name"]
        self.fed    = hash["country"]  if hash["country"]
        self.born   = hash["birthday"] if hash["birthday"]
        self.gender = hash["sex"]      if hash["sex"]
        self.title  = hash["title"]    if hash["title"]
        self.rating = hash["rating"]   if hash["rating"]
        self.games  = hash["games"]    if hash["games"]
        self.active = hash["flag"]
      end

      def id=(fideid)
        @id = fideid.to_i
        @id = nil if @id == 0
      end

      def name=(name)
        @last_name, @first_name = name.strip.squeeze(" ").split(/\s*,\s*/)
        @last_name = nil if last_name == ""
        @first_name = nil if first_name == ""
      end

      def fed=(country)
        country.upcase!
        @fed = country if country.match(/^[A-Z]{3}$/)
      end

      def born=(birthday)
        @born = birthday.to_i if birthday.match(/^(19|20)\d\d$/)
      end

      def gender=(sex)
        @gender = sex if sex.match(/^[MF]$/)
      end

      def title=(title)
        title.upcase!
        if title.match("^W?[GIFC]M")
          @title = title
        elsif title.match("^W[GIFC]")
          @title = "#{title}M"
        end
      end

      def rating=(rating)
        @rating = rating.to_i
        @rating = nil if @rating == 0
      end

      def games=(games)
        @games = games.to_i
      end

      def active=(flag)
        @active = flag && flag.match(/i/) ? false : true
      end

      def invalid?
        return "id"     unless id
        return "name"   unless last_name
        return "fed"    unless fed
        return "gender" unless gender
        return false
      end

      def to_s
        "#{id}|#{first_name}|#{last_name}|#{fed}|#{born}|#{gender}|#{title}|#{rating}|#{games}|#{active}"
      end

      def to_h
        [:id, :first_name, :last_name, :fed, :born, :gender, :title, :rating, :games, :active].inject({}){ |m, a| m[a] = send(a); m }
      end

      # This is used to create a CSV file to load into MySQL and must match the fide_players columns in order.
      def to_csv(created_at, updated_at)
        csv = Array.new
        csv.push id.to_s
        csv.push last_name.gsub(/\\/, "")
        csv.push first_name ? first_name.gsub(/\\/, "") : NULL
        csv.push fed
        csv.push title || NULL
        csv.push gender
        csv.push born ? born.to_s : NULL
        csv.push rating ? rating.to_s : NULL
        csv.push NULL # ICU ID
        csv.push created_at
        csv.push updated_at
        csv.join(",")
      end
    end

    class Parser < Nokogiri::XML::SAX::Document
      attr_reader :state, :total, :irish

      def initialize(&block)
        @block = block
        @attrs = Regexp.new("^(fideid|name|country|sex|title|rating|games|birthday|flag)$")
        @state = ""
      end

      def start_element(name, attr)
        if @state == "player" && @attrs.match(name)
          @state = name
        elsif @state == "playerslist" && name == "player"
          @state = name
          @player = Hash.new
        elsif @state == "" && name == "playerslist"
          @state = name
        end
      end

      def end_element(name)
        if @attrs.match(@state) && @attrs.match(name)
          @state = "player"
        elsif @state == "player" && name == "player"
          @state = "playerslist"
          @block.call(@player)
        elsif @state == "playerslist" && name == "playerslist"
          @state = ""
        end
      end

      def characters(string)
        if @attrs.match(@state)
          @player[@state] = string
        end
      end

      def error(string)
        raise SyncError.new("SAX error: #{string}")
      end
    end
  end
end
