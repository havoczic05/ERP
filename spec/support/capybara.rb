require "capybara/rspec"

Capybara.configure do |config|
  config.default_driver = :rack_test
  config.javascript_driver = :selenium_headless
end
