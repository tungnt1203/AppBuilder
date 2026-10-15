require "test_helper"

# One admin for all of someone's shops: each shop's people see that shop, and only its data.
class ShopAdmin::ShopsTest < ActionDispatch::IntegrationTest
  test "an owner with two shops runs both from one admin" do
    sign_in_as users(:member)

    get shop_admin_root_path(shops(:cats))
    assert_select "aside details a", "Chubby Cat Tees"
    assert_select "aside details a", "Good Boy Hoodies"

    get shop_admin_orders_path(shops(:cats))
    assert_select "a", /#1002/
    get shop_admin_orders_path(shops(:dogs))
    assert_select "a", text: /#1002/, count: 0 # the cats' orders aren't the dogs'
  end

  test "staff see only the shops they're members of" do
    sign_in_as users(:cats_staff)

    get shop_admin_root_path(shops(:cats))
    assert_response :success
    assert_select "aside details a", text: "Good Boy Hoodies", count: 0

    get shop_admin_root_path(shops(:dogs))
    assert_response :not_found
    in_shop(shops(:cats))
    get shop_admin_order_path(shops(:dogs), orders(:paid))
    assert_response :not_found
  end

  test "opens a new shop, owned by whoever opened it" do
    sign_in_as users(:cats_staff)

    get new_admin_shop_path
    assert_response :success
    post admin_shops_path, params: { shop: { name: "Sam's Socks", subdomain: "sams-socks", currency: "EUR" } }
    shop = Shop.find_by!(subdomain: "sams-socks")
    assert_redirected_to shop_admin_root_path(shop)
    assert_equal [ "owner", "EUR" ], [ shop.role_of(users(:cats_staff)), shop.currency ]

    get admin_shops_path
    assert_select "a[href=?]", shop_admin_root_path(shop)
    assert_select "a[href=?]", shop_admin_root_path(shops(:cats))
  end

  test "a taken or reserved address shows the form again" do
    sign_in_as users(:cats_staff)
    post admin_shops_path, params: { shop: { name: "Copy", subdomain: "chubby-cats", currency: "USD" } }
    assert_response :unprocessable_entity
    post admin_shops_path, params: { shop: { name: "Copy", subdomain: "admin", currency: "USD" } }
    assert_response :unprocessable_entity
    assert_select ".admin-alert", /Subdomain is reserved/
  end
end
