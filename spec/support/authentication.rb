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
  # Waits for the authenticated page to render before returning, so callers can
  # immediately visit the target page without a race condition.
  #
  # Why the retry loop: a Turbo post-load re-render of the login page can reset
  # the form just after it loads, wiping values typed before it fires. The submit
  # then carries empty required fields, is blocked by HTML5 validation, and never
  # reaches the server — so we stay on /login. The timing of that render varies
  # with machine load, so no fixed wait is reliable. Instead we attempt the full
  # flow and, if the authenticated nav ("Log out", which only exists once logged
  # in) doesn't appear, re-submit on a fresh page load until it does.
  def system_login_as(user)
    attempts = 0
    loop do
      attempts += 1
      visit login_path
      fill_in "Email", with: user.email
      fill_in "Password", with: "password123"
      click_button "Log in"
      return if page.has_button?("Log out", wait: 5)
      raise "system_login_as: login did not complete after #{attempts} attempts" if attempts >= 5
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :system
  config.include SystemAuthenticationHelper, type: :system
end
