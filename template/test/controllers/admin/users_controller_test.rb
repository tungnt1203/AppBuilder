require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "members cannot manage people" do
    sign_in_as users(:member)

    get admin_users_path
    assert_redirected_to root_path
  end

  test "admins see everyone" do
    sign_in_as users(:admin)

    get admin_users_path
    assert_response :success
    assert_select "li", count: User.count
  end

  test "inviting someone creates the user, emails them and shows the link" do
    sign_in_as users(:admin)

    assert_difference -> { User.count } do
      post admin_users_path, params: { user: { name: "Newcomer", email_address: "newcomer@example.com", role: "member" } }
    end

    user = User.find_by!(email_address: "newcomer@example.com")
    assert_enqueued_email_with InvitationsMailer, :invite, args: [ user ]
    assert_redirected_to admin_user_path(user)

    follow_redirect!
    assert_select "input[value*='/invitations/']"
  end

  test "nobody can be made owner through the form" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:member)), params: { user: { role: "owner" } }

    assert users(:member).reload.member?
  end

  test "admins can promote and remove members" do
    sign_in_as users(:admin)

    patch admin_user_path(users(:member)), params: { user: { role: "admin" } }
    assert users(:member).reload.admin?

    delete admin_user_path(users(:member))
    assert_not User.exists?(users(:member).id)
  end

  test "the owner cannot be removed" do
    sign_in_as users(:admin)

    delete admin_user_path(users(:owner))

    assert User.exists?(users(:owner).id)
    assert_redirected_to admin_users_path
  end

  test "admins cannot remove themselves" do
    sign_in_as users(:admin)

    delete admin_user_path(users(:admin))

    assert User.exists?(users(:admin).id)
  end
end
