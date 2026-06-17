module AuthenticationHelper
  # Stub ApplicationController#current_user for request and system specs.
  # Use allow_any_instance_of so the authenticate_user! guard sees the stubbed user
  # and the spec does not trigger a redirect to login.
  def login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :system
end
