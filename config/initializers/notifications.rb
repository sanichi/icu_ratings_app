ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, start, finish, id, payload|
  if payload[:exception]
    name = payload[:exception].first
    # Other ones to possibly ignore would be AbstractController::ActionNotFound and ActionController::RoutingError.
    unless name == "ActiveRecord::RecordNotFound"
      Failure.create!(:name => name, :details => payload.to_yaml)
    end
  end
end