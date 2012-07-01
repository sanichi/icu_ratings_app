module Tournaments
  class FideData
    attr_reader :status, :updates

    class Matches
      attr_reader :fid, :fed, :dob

      def initialize(fid, fed, dob, matches, max_samples=3)
        @fid, @fed, @dob = fid, fed, dob
        @matches = matches
        @max_samples = max_samples
      end

      def count
        @matches.count
      end

      def samples
        @matches.each_with_index.map do |p, i|
          case
          when i <  @max_samples then p
          when i == @matches.count - 1 then p
          when i == @max_samples then false      # signals "..."
          else nil
          end
        end.select{ |s| !s.nil? }
      end
      
      def sig
        [:fid, :fed, :dob].map{ |m| send(m) ? "T" : "F" }.join("")
      end
    end

    def initialize(tournament, update=false)
      @tournament = tournament
      @updates = @tournament.update_fide_data if update
      @status = []
      [true, false].each do |fid|
        [true, false].each do |fed|
          [true, false].each do |dob|
            match(fid, fed, dob)
          end
        end
      end
    end

    private

    def match(fid, fed, dob)
      matches = @tournament.players.order(:last_name, :first_name).where(sql(fid, fed, dob)).all
      @status.push Matches.new(fid, fed, dob, matches) if matches.count > 0
    end

    def sql(fid, fed, dob)
      sql = []
      sql.push term(fid, :fide_id)
      sql.push term(fed, :fed)
      sql.push term(dob, :dob)
      sql.join(" AND ")
    end

    def term(present, field)
      "players.#{field} IS #{present ? 'NOT ' : ''}NULL"
    end
  end
end
