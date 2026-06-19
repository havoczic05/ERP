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
  # We assert on a DOM element that only exists once logged in (the nav "Log out"
  # button) rather than on have_current_path: the login submit navigates through
  # Turbo, and checking the URL alone races against that navigation. Waiting for
  # content forces Capybara to synchronize with the rendered authenticated page.
  def system_login_as(user)
    visit login_path
    # Turbo runs a post-load render shortly after the page reports ready; it can
    # reset the form, wiping values typed before it fires (leaving the required
    # fields empty so the submit is blocked by HTML5 validation and never reaches
    # the server). Let the page settle — a driver round-trip plus a brief pause —
    # before filling so the typed values stick. This race only surfaces under the
    # cumulative slowdown of several sequential Selenium sessions in one run.
    page.has_css?("form input[type=email]", wait: 5)
    sleep 0.3
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    # Proves the session is established and the authenticated page has rendered.
    expect(page).to have_button("Log out")
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
  config.include AuthenticationHelper, type: :system
  config.include SystemAuthenticationHelper, type: :system
end
