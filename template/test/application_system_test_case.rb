require "test_helper"
require "capybara/cuprite"

# Tests that use the app the way people do, in headless Chrome: a customer orders on the site,
# the owner sees the order in /admin. Write one for each main flow (new-feature skill). Run with
# bin/rails test:system. On a failure Capybara saves a screenshot in tmp/capybara.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, screen_size: [ 1280, 800 ], options: {
    js_errors: true, # a JavaScript error on the page fails the test
    process_timeout: 30, timeout: 15,
    browser_options: { "no-sandbox" => nil } # needed when Chrome runs in a container
  }

  # Owner or staff, through /admin's sign-in screen, like a person. Fixtures' password is "password".
  def sign_in_as(user, password: "password")
    visit new_admin_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    find("form[action='#{admin_session_path}'] [type=submit]").click
    assert_no_current_path new_admin_session_path
  end

  # A customer, through the customers' site's sign-in screen.
  def sign_in_as_customer(customer, password: "password")
    visit new_session_path
    fill_in "email_address", with: customer.email_address
    fill_in "password", with: password
    find("form[action='#{session_path}'] [type=submit]").click
    assert_no_current_path new_session_path
  end

  # Most visitors are on a phone: on_phone { visit root_path; … }
  def on_phone
    page.driver.resize(390, 844)
    yield
  ensure
    page.driver.resize(1280, 800)
  end
end
