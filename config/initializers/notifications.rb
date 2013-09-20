ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, start, finish, id, payload|
  if payload[:exception]
    name = payload[:exception].first
    # Ignore certain exceptions (other candidates would be AbstractController::ActionNotFound and ActionController::RoutingError).
    unless %w[ActiveRecord::RecordNotFound ActionController::UnknownFormat].include?(name)
      # This next is mainly because to_yaml (used to prettify the details) can't handle anonymous modules (e.g. in :request).
      safe = [:controller, :action, :params, :format, :path, :exception]
      details = payload.select{|k,v| safe.include?(k)}.to_yaml
      # Create a failure to record this exception.
      Failure.create!(name: name, details: details);
    end
  end
end