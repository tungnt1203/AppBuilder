require "test_helper"
require "capybara/cuprite"

# Tests that use the shop the way buyers do, in headless Chrome. Run with bin/rails test:system.
# On a failure Capybara saves a screenshot in tmp/capybara.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, screen_size: [ 1280, 800 ], options: {
    js_errors: true, # a JavaScript error on the page fails the test
    process_timeout: 30, timeout: 15,
    browser_options: { "no-sandbox" => nil } # needed when Chrome runs in a container
  }

  Capybara.default_max_wait_time = 5

  # Most visitors are on a phone: on_phone { visit root_path; … }
  def on_phone
    page.driver.resize(390, 844)
    yield
  ensure
    page.driver.resize(1280, 800)
  end
end
