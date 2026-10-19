require "test_helper"

class ShopAdmin::PlatformRequestsTest < ActionDispatch::IntegrationTest
  setup do
    in_shop_admin
    @platform_request = ActsAsTenant.with_tenant(shops(:cats)) { PlatformRequest.create!(body: "Products need a material field") }
  end

  test "the shop's admins read what the storefront asked for; staff don't" do
    sign_in_as users(:cats_admin)
    get shop_admin_platform_requests_path
    assert_response :success
    assert_select "p", "Products need a material field"
    assert_select "span", "Waiting"
    assert_select "#platform_request_#{@platform_request.id} form", count: 0 # only the platform team changes them

    patch shop_admin_platform_request_path(@platform_request), params: { status: "done" }
    assert_equal "open", @platform_request.reload.status

    sign_in_as users(:cats_staff)
    get shop_admin_platform_requests_path
    assert_redirected_to shop_admin_root_path
  end

  test "the platform team marks a request done" do
    ShopMembership.create!(shop: shops(:cats), user: users(:owner), role: "admin")
    sign_in_as users(:owner)
    get shop_admin_platform_requests_path
    assert_select "#platform_request_#{@platform_request.id} form button", "Mark done"
    patch shop_admin_platform_request_path(@platform_request), params: { status: "done" }
    assert_redirected_to shop_admin_platform_requests_path
    assert_equal "done", @platform_request.reload.status
  end
end
