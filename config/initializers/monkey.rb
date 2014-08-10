# This is a monkey patch of actionpack/lib/action_controller/metal/instrumentation.rb
# in order to add IP and user agent into the raw payload. If an exception occurs
# the normal mechanism for customising the payload, append_info_to_payload, doesn't
# get called. Remove/amend this patch if Rails even fixes this of the method changes.

module ActionController
  module Instrumentation
    def process_action(*args)
      raw_payload = {
        :controller => self.class.name,
        :action     => self.action_name,
        :params     => request.filtered_parameters,
        :format     => request.format.try(:ref),
        :method     => request.method,
        :path       => (request.fullpath rescue "unknown"),
        # Path these two in for now because append_info_to_payload(payload) doesn't work with exceptions.
        :ip         => (request.remote_ip rescue "unknown"),
        :agent      => (request.env["HTTP_USER_AGENT"] rescue "unknown"),
      }

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        result = super
        payload[:status] = response.status
        append_info_to_payload(payload)
        result
      end
    end
  end
end
