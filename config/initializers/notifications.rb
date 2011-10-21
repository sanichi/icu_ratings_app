ActiveSupport::Notifications.subscribe "process_action.action_controller" do |name, start, finish, id, payload|
  if payload[:exception]
    Failure.create!(:name => payload[:exception].first, :details => payload.to_yaml)
  end
end