require "test_helper"

class ShopAdmin::SearchesControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_staff) }

  test "finds orders, customers, products and screens as the owner types" do
    get shop_admin_search_path(q: "lee")
    assert_select "turbo-frame#admin_search_results"
    assert_select "a[href=?]", shop_admin_order_path(orders(:paid))
    assert_select "a[href=?]", shop_admin_customer_path(orders(:paid).token)

    get shop_admin_search_path(q: "#1003")
    assert_select "a[href=?]", shop_admin_order_path(orders(:shipped))
    assert_select "a[href^=?]", shop_admin_customers_path, count: 0

    get shop_admin_search_path(q: "mug")
    assert_select "a[href=?]", edit_shop_admin_product_path(products(:mug))

    get shop_admin_search_path(q: "disc")
    assert_select "a[href=?]", shop_admin_discounts_path
    get shop_admin_search_path(q: "settings")
    assert_select "a", text: /Settings/, count: 0, message: "staff don't change settings"

    get shop_admin_search_path(q: "zzzz")
    assert_select "p", /Nothing matches/
  end
end
