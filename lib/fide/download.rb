require 'net/http'

module FIDE
  class Download
    SyncError = Class.new(StandardError)
    SyncInfo  = Class.new(StandardError)

    class Irish < Download
      def initialize
        @name = "Irish FIDE Players Synchronisation"
      end

      # Run periodically (roughly every week) to sync Irish FIDE players and ratings.
      # Since the number of Irish players is relatively small, we can afford to download
      # the full FIDE list, not ignore inactive players, track historical ratings and perfom
      # creates and updates through ActiveRecord. Use bin/rake sync:irish_fide_players[F]
      # to force a reread of a file already processed.
      def sync_fide_players(force=false)
        @start = Time.now
        @time = Hash.new
        begin
          get_download_details
          check_not_downloaded unless force
          download_and_save
          read_and_parse
          update_our_players
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

      def get_download_details
        uri = URI.parse("http://ratings.fide.com/download.phtml")
        res = Net::HTTP.get_response(uri)
        raise SyncError.new("unexpected response for download page (#{res.code})") unless res.code == "200"
        # <a href=http://ratings.fide.com/download/players_list.zip class=tur>Download full list of players (not rated included)</a>(TXT)
        # <small>(Updated: 30 Dec 2010, Size: 4 998 584 bytes)</small>
        raise SyncError.new("no links detected") unless res.body.match(/href=["']?(http:\/\/ratings.fide.com\/download\/players_list\.zip)['"]?[^>]*>[^<]+<\/a>[^<]*<small>([^<]+)<\/small>/)
        @link = $1
        note  = $2
        @file = "players_list.txt"
        raise SyncError.new("no updated date found in note") unless note.match(/Updated:\s+(\d[\d\w\s]+\d)\s*,/i)
        updated = Date.parse($1).to_s
        raise SyncError.new("no file size found in note") unless note.match(/Size:\s+(\d[\d\s]+\d)\s+bytes/i)
        size = $1.gsub(/\s/, '')
        @signature = [@file, updated, size].join(', ')
        @time['download'] = Time.now - @start
      end

      def read_and_parse
        zip = Zip::ZipFile.open(@zip.path)
        raise SyncError.new("zip file has no entry for #{@file}") unless zip.find_entry(@file)
        data = zip.read(@file)
        raise SyncError.new("unexpected zip data encoding (#{data.encoding.name})") unless data.encoding.name == "ASCII-8BIT"
        data.force_encoding("ISO-8859-1")
        data.encode!("UTF-8")
        lines = data.split(/\n\r?/)
        @nlines = lines.size
        raise SyncError.new("unexpected number of lines (#{lines.size})") unless @nlines > 250000
        if lines.first.match(/^ID\s*number\s*Name\s*Title?\s*Fed\s*((Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Nov|Dec)[a-z]*[12]\d)/i)
          lines.shift
          @period = check_period("1st #{$1}")
        else
          raise SyncError.new("unexpected first line of file (#{lines.first.chomp})")
        end
        @their_players = Hash.new
        @invalid = Array.new
        lineno = 1
        lines.each do |line|
          lineno += 1
          if line.match(/^\s*([1-9]\d*)\s+(.*[^\s])\s+([A-Z]{3}|\*)\s*(.*)$/)
            fed = $3
            if fed == 'IRL'
              id = $1.to_i
              raise SyncError.new("duplicate FIDE ID #{id} on line #{lineno}") if @their_players[id]
              name = $2.strip
              rest = $4.strip
              if name.match(/\s(w?[cfmg])$/)
                title = "#{$1.upcase}M"
                title.sub!(/MM/, 'IM') if title.match(/MM$/)
                name.sub!(/\s+(w?[cfmg])$/, '')
              end
              name.squeeze!(' ')
              ln, fn = name.split(/\s*,\s*/)
              if rest.match(/^([1-9]\d{2,3})\s+(0|[1-9]\d?\d?)\b/)
                rating = $1.to_i
                games = $2.to_i
              end
              born = $1 if rest =~ /((19|20)\d\d)[^\d]*$/
              gender = rest =~ /w/ ? 'F' : 'M'
              @their_players[id] = { last_name: ln, first_name: fn, title: title, fed: fed, rating: rating, games: games, born: born, gender: gender }
            end
          else
            @invalid.push("#{lineno}: #{line}") unless line.match(/^\s*(0\s*)?$/)
            raise SyncError.new("too many invalid lines") if @invalid.size >= 10
          end
        end
        @time['parse'] = Time.now - @start
      end

      def update_our_players
        @our_players = FidePlayer.all.inject({}) { |h,p| h[p.id] = p; h }
        @our_ratings = FideRating.find_all_by_period(@period).inject({}) { |h,r| h[r.fide_id] = r; h }
        @updates = []
        @creates = []
        @invalid = []
        @changes = Hash.new(0)
        @their_players.keys.each do |id|
          tplr = @their_players[id]
          oplr = @our_players[id]
          rating = tplr[:rating]
          games = tplr.delete(:games)
          if oplr
            tplr.keys.each { |key| oplr.send("#{key}=", tplr[key])}
            if oplr.changed?
              @updates.push(id)
              oplr.changed.each { |attr| @changes[attr] += 1 }
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
                  raise SyncError.new("too many invalid records") if @invalid.size > 10
                end
              else
                oplr.fide_ratings.create(period: @period, rating: rating, games: games)
                @changes[:rating] += 1 if @our_players[id]
              end
            end
          else
            @invalid.push("#{id} #{oplr.errors.inspect}")
            raise SyncError.new("too many invalid records") if @invalid.size > 10
          end
        end
        @time['update'] = Time.now - @start
      end

      def report
        str = Array.new
        str.push("link: #{@link}") if @link
        str.push("signature: #{@signature}") if @signature
        str.push("period: #{@period}") if @period
        str.push("total lines: #{@nlines}") if @nlines
        str.push("info: #{@info}") if @info
        str.push "records extracted: #{@their_players.size}" if @their_players
        str.push "records existing: #{@our_players.size}" if @our_players
        str.push "creates: #{summarize_list(@creates)}" if @creates
        str.push "updates: #{summarize_list(@updates)}" if @updates
        str.push "changes: #{summarize_changes}" if @changes
        str.concat summarize_time(@time) if @time.size > 0
        str.push "invalid: #{summarize_invalid}" if @invalid
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
        @changes.keys.sort.map { |key| "#{key}: #{@changes[key]}" }.join(", ")
      end
    end

    class Other < Download
      def initialize
        @name = "Non-Irish FIDE Players Synchronisation"
      end

      # Run periodically (roughly weekly) to sync non-Irish FIDE players and ratings.
      # Since the number of such players is large, we download the latest list (smaller
      # than the full list), ignore inactive players, only track the latest rating, avoid
      # ActiveRecord and instead perform updates by creating a file and loading it into MySQL.
      # Use bin/rake sync:other_fide_players[F] to force a reread of a file already processed.
      def sync_fide_players(force=false)
        @start = Time.now
        @time = Hash.new
        begin
          get_download_details
          check_not_downloaded unless force
          download_and_save
          extract_and_save
          transform_and_save
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

      def get_download_details
        uri = URI.parse("http://ratings.fide.com/download.phtml")
        res = Net::HTTP.get_response(uri)
        raise SyncError.new("unexpected response for download page (#{res.code})") unless res.code == "200"
        # <a href=http://ratings.fide.com/download/may11frl.zip class=tur>Download May 2011 FRL</a>(TXT)
        # <small>(Updated: 30 May 2011, Size: 2 656 668 bytes)</small><br>
        raise SyncError.new("no links detected") unless res.body.match(/href=["']?(http:\/\/ratings.fide.com\/download\/(jan|feb|mar|apr|may|jun|jul|aug|sep|nov|dec)(\d\d)frl\.zip)['"]?[^>]*>[^<]+<\/a>[^<]*<small>([^<]+)<\/small>/)
        @link, month, year, note = $1, $2, $3, $4
        @file = "#{month}#{year}frl.txt"
        @period = check_period("1st #{month} #{year}")
        raise SyncError.new("no updated date found in note") unless note.match(/Updated:\s+(\d[\d\w\s]+\d)\s*,/i)
        updated = Date.parse($1).to_s
        raise SyncError.new("no file size found in note") unless note.match(/Size:\s+(\d[\d\s]+\d)\s+bytes/i)
        size = $1.gsub(/\s/, '')
        @signature = [@file, updated, size].join(', ')
        @time['download'] = Time.now - @start
      end

      # Extract and save the relevant file from the ZIP archive.
      def extract_and_save
        zip = Zip::ZipFile.open(@zip.path)
        file = Tempfile.new("fide_ratings.txt")
        @data = file.path
        file.close!
        success = zip.extract(@file, @data)
        raise SyncError.new("zip file has no entry for #{@file}") unless success
        raise SyncError.new("extracted file is empty") unless File.size?(@data)
        @time['extraction'] = Time.now - @start
      end

      # Transform the extracted data file into MySQL CVS format for quick upload.
      def transform_and_save
        # This time we save to a local directory to help ensure MySQL can access it.
        @csv = "#{Rails.root}/tmp/fide_ratings.csv"

        # Initialise.
        file = File.open(@csv, "w")
        @invalid = Array.new
        @inactive = 0
        @records = 0
        @count = 0
        got_id = Hash.new
        created_at = Time.now.to_s(:db)
        updated_at = created_at
        icu_id = '\N'

        # Read the previously saved data file line by line.
        File.open(@data, encoding: "ISO-8859-1").each_line do |line|
          line.chomp!
          @count+= 1

          # Check the header line.
          if (@count == 1)
            unless line.match(/^ID\s*number\s*Name\s*Title?\s*Fed\s*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Nov|Dec)[a-z]*[12]\d/i)
              raise SyncError.new("unexpected first line of file: #{line}")
            end
            next
          end

          # Process the other lines.
          if line.match(/i\s*$/)
            # Skip inactive players. It's unfortunate to have to do this, but we
            # need to reduce the amount of data to process (and later search).
            @inactive+= 1
            next
          elsif line.match(/^\s*([1-9]\d*)\s+(.*[^\s])\s+([A-Za-z]{3}|\*)\s*(.*)$/)
            # ID name and federation. "*" is quite common for federation, so just skip it.
            id = $1.to_i
            name = $2.strip
            fed = $3.upcase
            rest = $4.strip
            if got_id[id]
              @invalid.push("line #{@count}, duplicate ID: #{line}")
              next
            end
            next unless fed.length == 3

            # Skip Irish players as they are synchronised using a different strategy (see FIDE::Download::Irish).
            next if fed == 'IRL'

            # Split and tidy up the name and get the rest of the player's data: title, rating, games, gender, birth year.
            if name.match(/\s(w?[cfmg])$/)
              title = "#{$1.upcase}M"
              title.sub!(/MM/, 'IM') if title.match(/MM$/)
              name.sub!(/\s+(w?[cfmg])$/, '')
            else
              title = '\N'
            end
            name.squeeze!(' ')
            last_name, first_name = name.split(/\s*,\s*/)

            # Remove backslashes (the MySQL escape character for loading files) from the name.
            last_name.gsub!(/\\/, "")
            first_name.gsub!(/\\/, "") if first_name
            if last_name.length == 0
              @invalid.push("line #{@count}, invalid name: #{line}")
              next
            end

            # Convert to UFF-8 (although I think it's all ASCII anyway).
            # This assumes that the MySQL variable character_set_database is set to utf8.
            last_name.encode!("UTF-8")
            first_name.encode!("UTF-8") if first_name

            # Make sure blank first names convert to NULL in the database.
            first_name = '\N' if first_name.nil? || first_name == ""

            # Rating and games, if there are any.
            if rest.match(/^([1-9]\d{2,3})\s+(0|[1-9]\d?\d?)\b/)
              rating = $1.to_i
              games = $2.to_i
            else
              rating = '\N'
              games = '\N'
            end

            # Year of birth and gender.
            born = rest =~ /((19|20)\d\d)[^\d]*$/ ? $1 : '\N'
            gender = rest =~ /w/ ? 'F' : 'M'
            got_id[id] = true

            # Write the data out to the file that later we will load into MySQL. ActiveRecord is far too slow
            # with this amount of data. The table columns have to be in a particular order for this to work.
            file.write "#{id},#{last_name},#{first_name},#{fed},#{title},#{gender},#{born},#{rating},#{icu_id},#{created_at},#{updated_at}\n"
            @records+= 1
          else
            @invalid.push("line #{@count}, invalid: #{line}") unless line.match(/^\s*(0\s*)?$/)
          end
          raise SyncError.new("too many invalid lines") if @invalid.size >= 10
        end
        file.close

        # Testing, testing
        raise SyncError.new("unexpectedly low number of lines: #{@count}") unless @count > 120000
        raise SyncError.new("unexpectedly low number of inactive: #{@inactive}") unless @inactive > 40000
        @time['transform'] = Time.now - @start
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
        str.push("period: #{@period}") if @period
        str.push("total lines: #{@count}") if @count
        str.push("info: #{@info}") if @info
        str.push "records extracted: #{@records}" if @records
        str.push "inactive players skipped: #{@inactive}" if @inactive
        str.push "records before load: #{@records_before_load}" if @records_before_load
        str.push "records after load: #{@records_after_load}" if @records_after_load
        str.concat summarize_time(@time) if @time.size > 0
        str.push "invalid: #{summarize_invalid}" if @invalid
        str.push "error: #{@error}" if @error
        str.join("\n")
      end
    end

    private

    def check_not_downloaded
      already_done = Event.where("name = '#{@name}' AND success = 1 AND report LIKE '%signature: #{@signature}%'").order('created_at asc')
      raise SyncInfo.new("already done on #{already_done.first.created_at}") if already_done.size > 0
    end

    def download_and_save
      uri = URI.parse(@link)
      res = Net::HTTP.get_response(uri)
      raise SyncError.new("unexpected response for download file (#{res.code})") unless res.code == "200"
      raise SyncError.new("unexpected content-type (#{res.content_type})") unless res.content_type == "application/x-zip-compressed"
      raise SyncError.new("unexpected zip archive encoding (#{res.body.encoding.name})") unless res.body.encoding.name == "ASCII-8BIT"
      @zip = Tempfile.new("fide_ratings.zip")
      @zip.syswrite(res.body)
      @zip.close
    end

    def summarize_invalid
      return "none" if @invalid.size == 0
      "#{@invalid.size}\n#{@invalid.join("\n")}"
    end

    def summarize_time(time)
      time.keys.map { |key| "seconds after #{key}: #{'%.1f' % time[key]}" }
    end

    def check_period(period)
      begin
        date = Date.parse(period)
      rescue
        raise SyncError.new("invalid rating period (#{period})")
      end
      today = Date.today
      diff = (today - date).to_i
      raise SyncError.new("rating period (#{period}) is in the future") if diff < 0
      raise SyncError.new("rating period (#{period}) is too far in the past") if diff > 90
      date
    end

    def event(success)
      Event.create(name: @name, report: report, time: (Time.now - @start).to_i, success: success)
    end
  end
end
