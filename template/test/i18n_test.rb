require "test_helper"

class I18nScreensTest < ActionDispatch::IntegrationTest
  setup { enable_customer_accounts }

  test "built-in screens have no missing translations" do
    [ root_path, new_session_path, new_registration_path, new_password_path, new_admin_session_path, new_admin_password_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end

    sign_in_as_customer customers(:casey)
    [ account_path, edit_account_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end

    sign_in_as users(:owner)
    [ admin_root_path, admin_users_path, new_admin_user_path, edit_admin_user_path(users(:staff)), admin_user_path(users(:staff)) ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end
  end

  private
    def assert_no_missing_translations
      assert_no_match(/translation missing|Translation missing/i, response.body, "Missing translation on #{request.path}")
    end
end
