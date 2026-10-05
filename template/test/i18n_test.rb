require "test_helper"

class I18nTest < ActiveSupport::TestCase
  test "every built-in English text has a Vietnamese translation" do
    english = flatten_keys(YAML.load_file(Rails.root.join("config/locales/en.yml"))["en"])
    vietnamese = flatten_keys(YAML.load_file(Rails.root.join("config/locales/vi.yml"))["vi"])

    # Vietnamese has no singular form, so the plural "one" keys are not needed.
    missing = english - vietnamese - english.grep(/\.one\z/)
    assert_empty missing, "Missing in config/locales/vi.yml"
  end

  test "built-in screens render in Vietnamese" do
    I18n.with_locale(:vi) do
      assert_equal "Đăng nhập", I18n.t("sessions.new.title")
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
    @default_locale, @locale = I18n.default_locale, I18n.locale
    I18n.default_locale = I18n.locale = :vi
  end

  teardown do
    I18n.default_locale, I18n.locale = @default_locale, @locale
  end

  test "built-in screens have no missing Vietnamese translations" do
    get new_session_path
    assert_select "h1", "Đăng nhập"
    assert_no_missing_translations

    get new_password_path
    assert_no_missing_translations

    sign_in_as users(:owner)
    [ root_path, admin_users_path, new_admin_user_path, edit_admin_user_path(users(:member)), admin_user_path(users(:member)) ].each do |path|
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
