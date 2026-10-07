require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "administrators see every account with its apps" do
    sign_in_as users(:owner)

    get admin_users_path

    assert_response :success
    assert_select "#{"#" + ActionView::RecordIdentifier.dom_id(users(:member))}", /Minh.*0 apps/m
    assert_select "#{"#" + ActionView::RecordIdentifier.dom_id(users(:owner))}", /2 apps/
  end

  test "members can't reach accounts" do
    sign_in_as users(:member)

    get admin_users_path
    assert_response :not_found

    patch admin_user_path(users(:member)), params: { user: { role: "admin" } }
    assert users(:member).reload.member?
  end

  test "an administrator makes another account an admin and back" do
    sign_in_as users(:owner)

    patch admin_user_path(users(:member)), params: { user: { role: "admin" } }
    assert users(:member).reload.admin?

    patch admin_user_path(users(:member)), params: { user: { role: "member" } }
    assert users(:member).reload.member?
  end

  test "the owner stays the owner" do
    users(:member).update!(role: :admin)
    sign_in_as users(:member)

    patch admin_user_path(users(:owner)), params: { user: { role: "member" } }
    assert users(:owner).reload.owner?

    delete admin_user_path(users(:owner))
    assert User.exists?(users(:owner).id)
  end

  test "removes accounts without apps only" do
    sign_in_as users(:owner)
    Project.create!(name: "Quán cà phê", language: "vi", owner: users(:member))

    delete admin_user_path(users(:member))
    assert User.exists?(users(:member).id)

    users(:member).projects.delete_all
    delete admin_user_path(users(:member))
    assert_not User.exists?(users(:member).id)
  end
end
