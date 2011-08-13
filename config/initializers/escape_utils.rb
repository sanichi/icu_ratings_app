# Added to fix warnings like the following in tests:
#
# /Users/mjo/.rvm/gems/ruby-1.9.2-p0/gems/rack-1.2.2/lib/rack/utils.rb:16: warning: regexp match /.../n against to UTF-8 string
#
# As described by http://openhood.com/rack/ruby/2010/07/15/rack-test-warning/.
# Also added the two require lines as recommended.
#

require "escape_utils/html/rack"
require "escape_utils/html/haml"

module Rack
  module Utils
    def escape(s)
      EscapeUtils.escape_url(s)
    end
  end
end
