require "test_helper"

class ShopSwitchTest < ActionDispatch::IntegrationTest
  test "without the shop, its pages don't exist and nothing links to them" do
    disable_shop

    get root_path
    assert_response :success
    assert_select "a[href='#{products_path}']", count: 0
    assert_select "#cart-link", count: 0

    get products_path
    assert_response :not_found
    get product_path(products(:tee))
    assert_response :not_found
    get cart_path
    assert_response :not_found
    post cart_items_path, params: { variant_id: variants(:mug).id }
    assert_response :not_found
    get new_checkout_path
    assert_response :not_found
    get order_path(orders(:paid))
    assert_response :not_found

    Store.current.update!(privacy_policy: "We keep your email to answer you.")
    get policy_path("privacy")
    assert_response :success
    get contact_path
    assert_response :success
  end

  test "without the shop, /admin hides it and keeps the rest" do
    disable_shop
    sign_in_as users(:owner)

    get admin_root_path
    assert_response :success
    assert_select "nav a[href='#{admin_orders_path}']", count: 0
    assert_select "nav a[href='#{admin_products_path}']", count: 0

    get admin_products_path
    assert_response :not_found
    get admin_orders_path
    assert_response :not_found
    get admin_agents_path
    assert_response :not_found

    get edit_admin_settings_path
    assert_response :success
    assert_select "#payments", count: 0
    assert_select "a[href='#{edit_admin_policies_path}']"
    get admin_users_path
    assert_response :success
  end

  test "a booking app without the shop sends visitors to book" do
    disable_shop
    enable_booking

    get root_path
    assert_select "a[href='#{new_booking_path}']"
    get new_booking_path
    assert_response :success
  end
end
