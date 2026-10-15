require "test_helper"

class ShopAdmin::MembershipsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { in_shop_admin }
  setup { sign_in_as users(:member) }

  test "the owner adds someone who has an account" do
    post shop_admin_memberships_path, params: { membership: { email_address: "Owner@example.com", role: "admin" } }
    assert_redirected_to shop_admin_memberships_path
    assert_equal "admin", shops(:cats).role_of(users(:owner))
    assert_no_enqueued_emails
  end

  test "someone new gets an account and an invitation to choose a password" do
    assert_enqueued_email_with InvitationsMailer, :invite, args: ->(args) { args.second == shops(:cats) } do
      post shop_admin_memberships_path, params: { membership: { email_address: "kim@example.com", name: "Kim", role: "staff" } }
    end
    kim = User.find_by!(email_address: "kim@example.com")
    assert_equal [ "Kim", "staff" ], [ kim.name, shops(:cats).role_of(kim) ]
    follow_redirect!
    assert_select "[role=status]", /Kim was added and emailed a link/
  end

  test "a bad email shows the form again" do
    post shop_admin_memberships_path, params: { membership: { email_address: "nope", role: "staff" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Email address is invalid/
  end

  test "changes what someone can do, and takes them off" do
    membership = shop_memberships(:cats_staff)
    patch shop_admin_membership_path(membership), params: { membership: { role: "admin" } }
    assert_equal "admin", membership.reload.role

    delete shop_admin_membership_path(membership)
    assert_not ShopMembership.exists?(membership.id)
    assert_not users(:cats_staff).shops.exists?
  end

  test "a shop keeps an owner" do
    owner = shop_memberships(:cats_owner)
    patch shop_admin_membership_path(owner), params: { membership: { role: "staff" } }
    assert_equal "owner", owner.reload.role
    follow_redirect!
    assert_select "[role=alert]", /needs an owner/
  end

  test "only owners manage the shop's people; admins run its settings, staff neither" do
    sign_in_as users(:cats_admin)
    get shop_admin_memberships_path
    assert_redirected_to shop_admin_root_path
    get edit_shop_admin_settings_path
    assert_response :success
    assert_select "aside a", text: "People", count: 0

    sign_in_as users(:cats_staff)
    get edit_shop_admin_settings_path
    assert_redirected_to shop_admin_root_path
    assert_select "aside a", text: "Settings", count: 0
  end
end
