require "test_helper"

class I18nTest < ActiveSupport::TestCase
  test "every built-in English text has a Vietnamese translation" do
    english = Rails.root.glob("config/locales/{en,*.en}.yml").flat_map { |file| flatten_keys(YAML.load_file(file)["en"]) }
    vietnamese = Rails.root.glob("config/locales/{vi,*.vi}.yml").flat_map { |file| flatten_keys(YAML.load_file(file)["vi"]) }

    # Vietnamese has no singular form, so the plural "one" keys are not needed.
    missing = english - vietnamese - english.grep(/\.one\z/)
    assert_empty missing, "Missing in the Vietnamese locale files (config/locales/*vi.yml)"
  end

  test "built-in screens render in Vietnamese" do
    I18n.with_locale(:vi) do
      assert_equal "Đăng nhập", I18n.t("admin.sessions.new.title")
      assert_equal "Quản trị viên", users(:admin).role_name
      assert_match "Có 2 lỗi", I18n.t("ui.form_errors.heading", count: 2)
    end
  end

  private
    def flatten_keys(hash, prefix = nil)
      hash.flat_map do |key, value|
        path = [ prefix, key ].compact.join(".")
        value.is_a?(Hash) ? flatten_keys(value, path) : path
      end
    end
end

class I18nScreensTest < ActionDispatch::IntegrationTest
  setup do
    enable_customer_accounts
    @default_locale, @locale = I18n.default_locale, I18n.locale
    I18n.default_locale = I18n.locale = :vi
  end

  teardown do
    I18n.default_locale, I18n.locale = @default_locale, @locale
  end

  test "built-in screens have no missing Vietnamese translations" do
    [ root_path, new_session_path, new_registration_path, new_password_path, new_admin_session_path, new_admin_password_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
      assert_select "h1", "Đăng nhập" if path == new_session_path
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
