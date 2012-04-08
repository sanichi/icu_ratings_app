# For generating SQL queries relating to alternative first or last names (see ICU::Name).
module ICU
  module Util
    module AlternativeNames
      def last_name_like(last, first)
        ICU::Name.new(first, last).alternatives(:last).push(last).map do |nam|
          "last_name LIKE '%#{quote_str(nam)}%'"
        end.sort.join(" OR ")
      end
    
      def first_name_like(first, last)
        ICU::Name.new(first, last).alternatives(:first).push(first).map do |nam|
          "first_name LIKE '%#{quote_str(nam)}%'"
        end.sort.join(" OR ")
      end
    
      private
    
      # Same as Rails version (ActiveRecord::ConnectionAdapters::Quoting).
      def quote_str(s)
        s.gsub(/\\/, '\&\&').gsub(/'/, "''")
      end
    end
  end
end
