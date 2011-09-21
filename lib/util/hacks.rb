require 'mime/types'

module Util
  class Hacks
    # Need to persuade MIME::Types to regard "tab" (a popular ending for Krause files)
    # as signaling a text/plain file type so that file uploads in Capybara will work.
    # The following is ugly and it causes a warning to stderr, but I don't see a better way yet.
    # http://stackoverflow.com/questions/7477517/how-to-add-to-the-extensions-for-an-existing-type-in-rubys-mimetypes/7477635.
    def self.fix_mime_types
      orig_stderr = $stderr
      $stderr = File.new('/dev/null', 'w')

      text_plain = MIME::Types['text/plain'].first.to_hash
      text_plain['Extensions'].push('tab')
      MIME::Types.add(MIME::Type.from_hash(text_plain))

      $stderr = orig_stderr
    end
  end
end
