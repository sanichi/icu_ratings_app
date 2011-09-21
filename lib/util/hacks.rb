require 'mime/types'

module Util
  class Hacks
    def self.fix_mime_types
      # Prepare to hide a warning message.
      orig_stderr = $stderr
      $stderr = File.new('/dev/null', 'w')

      # Don't see a better way to do this.
      # http://stackoverflow.com/questions/7477517/how-to-add-to-the-extensions-for-an-existing-type-in-rubys-mimetypes/7477635.
      text_plain = MIME::Types['text/plain'].first.to_hash
      text_plain['Extensions'].push('tab')
      MIME::Types.add(MIME::Type.from_hash(text_plain))

      # Restore the real stderr.
      $stderr = orig_stderr
    end
  end
end
