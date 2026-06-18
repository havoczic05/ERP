module AuthenticationHelper
  # Stub ApplicationController#current_user for request and system specs.
  # Use allow_any_instance_of so the authenticate_user! guard sees the stubbed user
  # and the spec does not trigger a redirect to login.
  #
  # IMPORTANT: this stub is in-process only. It does NOT cross into the Capybara
  # server thread under Selenium drivers. Do NOT use login_as for js: true examples.
  # Use system_login_as instead (real UI login via browser form).
  def login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end
end

module SystemAuthenticationHelper
  # Authenticate via real browser form submission for JS/Selenium system specs.
  # login_as (stub) does not cross thread boundaries under Selenium, so browser-driven
  # specs must go through the actual session controller.
  #
  # Requires the user's password to be 'password123' (FactoryBot default).
  #
  # Waits for the post-login redirect to root_path to complete before returning,
  # so callers can immediately visit the target page without a race condition.
  def system_login_as(user)
    visit login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    # Wait for the redirect to land on root — proves the session is established.
    expect(page).to have_current_path(root_path)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :system
  config.include SystemAuthenticationHelper, type: :system
end
