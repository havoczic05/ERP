require "capybara/rspec"

Capybara.configure do |config|
  config.default_driver = :rack_test
  config.javascript_driver = :selenium_headless
end

# ---------------------------------------------------------------------------
# Headless Chrome driver for JS-tagged system specs.
#
# Uses --headless=new (Chrome 112+), --no-sandbox and --disable-dev-shm-usage
# for WSL2 and Docker compatibility. Selenium Manager (selenium-webdriver 4.x)
# auto-resolves chromedriver — no manual binary needed.
# ---------------------------------------------------------------------------
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1400")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# ---------------------------------------------------------------------------
# Chrome-presence guard.
# Skip JS examples (not fail) when no Chrome binary is found.
# This keeps the suite green on Chrome-less CI runners while running for real
# where Chrome is available.
# ---------------------------------------------------------------------------
CHROME_PRESENT = %w[google-chrome google-chrome-stable chromium chromium-browser].any? do |binary|
  system("which #{binary} > /dev/null 2>&1")
end

require "database_cleaner/active_record"

# ---------------------------------------------------------------------------
# Database cleanup strategy for JS/Selenium system specs.
#
# WHY THIS IS NEEDED:
# Rails' use_transactional_fixtures wraps each test in a DB transaction that
# is rolled back after the example. This works fine for rack_test (in-process),
# but Capybara's Puma server runs in a separate thread. Each Puma request gets
# its own connection from the pool — outside the test transaction — so
# Factory-created records are NOT visible to the browser.
#
# SOLUTION: for js: true examples, disable transactional fixtures and switch to
# DatabaseCleaner's :truncation strategy. Records are committed to the DB and
# therefore visible to all threads. DatabaseCleaner truncates all tables after
# each example to restore a clean state.
#
# Non-JS examples keep the faster transaction strategy unchanged.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# NoTransactionForJS: a Concern included into js: true example groups.
#
# Overrides run_in_transaction? at the INSTANCE level so that setup_fixtures
# does not open a wrapping DB transaction. This is necessary because
# Capybara's Puma server runs in a separate thread and cannot see the test
# transaction — records created in the test are invisible to the browser.
#
# We override run_in_transaction? rather than setting the class attribute
# use_transactional_tests because rspec-rails sets that class attribute at
# include time (before any hooks). run_in_transaction? is called from
# setup_fixtures → setup_transactional_fixtures? and is checked per instance,
# so an instance-level override takes effect correctly.
# ---------------------------------------------------------------------------
module NoTransactionForJS
  def run_in_transaction?
    false
  end
end

RSpec.configure do |config|
  # Include the no-transaction override for all js: true example groups.
  # This fires at class-composition time, before before_setup, so
  # setup_fixtures sees run_in_transaction? == false and skips the wrapping
  # transaction.
  config.include NoTransactionForJS, :js

  # Guard runs first so chrome-absent envs skip rather than error on setup.
  config.before(:each, :js) do
    skip "Chrome not available in this environment" unless CHROME_PRESENT
  end

  # Wire js: true examples to the headless_chrome driver.
  config.before(:each, :js) do
    driven_by(:headless_chrome)
  end

  # ---------------------------------------------------------------------------
  # DatabaseCleaner for JS examples.
  #
  # Since there is no wrapping transaction, DatabaseCleaner's :truncation
  # strategy explicitly cleans tables after each example to ensure isolation.
  # ---------------------------------------------------------------------------
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each, :js) do |example|
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
    example.run
    DatabaseCleaner.clean
  end
end
