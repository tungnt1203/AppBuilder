require "test_helper"

class Admin::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_admin_password_path
    assert_response :success
  end

  test "create" do
    post admin_passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with Admin::PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_admin_session_path

    follow_redirect!
    assert_notice I18n.t("admin.passwords.create.notice")
  end

  test "create for an unknown user redirects but sends no mail" do
    post admin_passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_admin_session_path

    follow_redirect!
    assert_notice I18n.t("admin.passwords.create.notice")
  end

  test "edit" do
    get edit_admin_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_admin_password_path("invalid token")
    assert_redirected_to new_admin_password_path

    follow_redirect!
    assert_notice I18n.t("admin.passwords.invalid")
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put admin_password_path(@user.password_reset_token), params: { password: "new", password_confirmation: "new" }
      assert_redirected_to new_admin_session_path
    end

    follow_redirect!
    assert_notice I18n.t("admin.passwords.update.notice")
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put admin_password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_admin_password_path(token)
    end

    follow_redirect!
    assert_notice I18n.t("admin.passwords.update.alert")
  end

  private
    # Looks up the text through I18n so the test passes in any default locale.
    def assert_notice(text)
      assert_select "div", text: text
    end
end
