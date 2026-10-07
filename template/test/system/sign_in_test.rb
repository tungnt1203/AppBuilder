require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "the owner signs in to /admin and out" do
    sign_in_as users(:owner)
    assert_text users(:owner).name

    click_on I18n.t("layouts.admin.sign_out")
    assert_current_path new_admin_session_path
  end

  test "staff sign in on a phone" do
    on_phone { sign_in_as users(:staff) }
  end

  test "a visitor creates a customer account on a phone and signs out" do
    enable_customer_accounts

    on_phone do
      visit root_path
      click_on I18n.t("layouts.site.sign_in")
      click_on I18n.t("sessions.new.sign_up")
      fill_in Customer.human_attribute_name(:name), with: "Riley Shopper"
      fill_in Customer.human_attribute_name(:email_address), with: "riley@example.com"
      fill_in Customer.human_attribute_name(:password), with: "longenough"
      click_on I18n.t("registrations.new.submit")

      assert_selector "h1", text: "Riley Shopper"
      click_on I18n.t("accounts.show.sign_out")
      assert_current_path root_path
    end
  end
end
