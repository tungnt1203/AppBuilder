require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.invite(name: "Kim", email_address: "kim@example.com")
    shops(:cats).memberships.create!(user: @user, role: "staff")
    @token = @user.generate_token_for(:invitation)
  end

  test "someone added to a shop chooses a password and lands in its admin" do
    get invitation_path(@token)
    assert_select "h1", /Welcome, Kim/

    put invitation_path(@token), params: { user: { password: "a new password" } }
    assert_redirected_to shop_admin_root_path(shops(:cats))
    assert User.authenticate_by(email_address: "kim@example.com", password: "a new password")

    get invitation_path(@token) # works once
    assert_redirected_to new_session_path
  end

  test "a short password shows the form again" do
    put invitation_path(@token), params: { user: { password: "short" } }
    assert_response :unprocessable_entity
  end
end
