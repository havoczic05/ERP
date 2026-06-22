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
  # Why this drives the form through JavaScript instead of fill_in/click_button:
  # under headless Chrome on WSL2, on repeated logins within one persistent
  # browser session, keystroke delivery to the password field is intermittently
  # dropped before the page settles — the field stays blank, the submit is
  # blocked by HTML5 required validation, and we silently stay on /login (no
  # amount of re-typing recovers it within the example). A coordinate click on
  # the submit button is likewise occasionally swallowed.
  #
  # Setting the field values and calling requestSubmit() in one script runs over
  # CDP, so it bypasses the flaky input-event delivery entirely while still
  # exercising the real session controller (requestSubmit fires HTML5 validation
  # and the Turbo-handled submit). This is auth setup, not a test of the login
  # form itself — that is covered by the non-JS sessions/authentication specs.
  # We then wait on the authenticated nav ("Log out", only present once logged
  # in) so callers can visit the target page without a login race.
  PASSWORD = "password123" # FactoryBot default

  def system_login_as(user)
    visit login_path
    page.execute_script(<<~JS, user.email, PASSWORD)
      document.querySelector('input[type="email"]').value = arguments[0];
      document.querySelector('input[type="password"]').value = arguments[1];
      document.querySelector('form').requestSubmit();
    JS
    expect(page).to have_button("Cerrar sesión")
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :system
  config.include SystemAuthenticationHelper, type: :system
end
