module ICU
  module Util
    module Model
      # Get the base part of a file name, without allowing any dubious characters.
      def base_part_of(file_name)
        ::File.basename(file_name).gsub(/[^\w._-]/, '')
      end
    end
  end
end
