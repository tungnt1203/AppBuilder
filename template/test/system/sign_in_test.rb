require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "the owner signs in and out" do
    sign_in_as users(:owner)
    assert_text users(:owner).name

    click_on I18n.t("layouts.application.sign_out")
    assert_current_path new_session_path
  end

  test "signing in works on a phone" do
    on_phone { sign_in_as users(:member) }
  end
end
