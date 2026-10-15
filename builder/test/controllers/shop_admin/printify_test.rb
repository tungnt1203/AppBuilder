require "test_helper"

class ShopAdmin::PrintifyTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  test "an admin connects Printify, picking the shop when there are several" do
    printify = connect_fake_printify
    Store.current.update!(printify_token: nil, printify_shop_id: nil)
    printify.shop_list = [ FakePrintifyGateway::SHOP, { "id" => 77, "title" => "Second shop" } ]
    sign_in_as users(:cats_admin)

    get shop_admin_printify_connection_path
    assert_select "input[name=token]"

    post shop_admin_printify_connection_path, params: { token: "fake-token" }
    follow_redirect!
    assert_select "select[name='store[printify_shop_id]'] option", 2

    patch shop_admin_printify_connection_path, params: { store: { printify_shop_id: "77" } }
    assert_equal [ "77", "Second shop" ], Store.current.values_at(:printify_shop_id, :printify_shop_title)
    follow_redirect!
    assert_select "a[href=?]", shop_admin_printify_imports_path

    patch shop_admin_printify_connection_path, params: { store: { printify_send_to_production: "0", printify_shipping_method: "2" } }
    assert_equal [ false, 2 ], Store.current.values_at(:printify_send_to_production, :printify_shipping_method)

    delete shop_admin_printify_connection_path
    assert_not Store.current.printify_connected?
  end

  test "a token Printify refuses is said so" do
    printify = connect_fake_printify
    Store.current.update!(printify_token: nil, printify_shop_id: nil)
    printify.error = "Printify didn't accept the token."
    sign_in_as users(:cats_admin)

    post shop_admin_printify_connection_path, params: { token: "nope" }
    follow_redirect!
    assert_select "div", /didn't accept the token/
  end

  test "only admins connect Printify" do
    sign_in_as users(:cats_staff)
    get shop_admin_printify_connection_path
    assert_response :redirect
    assert_not_equal shop_admin_printify_connection_path, URI(response.location).path
  end

  test "staff import a Printify product into the shop" do
    connect_fake_printify
    sign_in_as users(:cats_staff)

    get shop_admin_products_path
    assert_select "a[href=?]", shop_admin_printify_imports_path

    get shop_admin_printify_imports_path
    assert_select "li", /Sunset Tee/
    assert_select "li", /From \$25\.00 · costs \$11\.50 · 54% margin/
    assert_select "button", "Import"

    assert_difference -> { Product.count } do
      post shop_admin_printify_imports_path, params: { printify_product_id: "pf-tee" }
    end
    product = Product.find_by!(printify_product_id: "pf-tee")
    assert product.draft?
    assert_redirected_to edit_shop_admin_product_path(product)
    follow_redirect!
    assert_select "h2", "Before it goes on sale"
    assert_select "a[href='#size_guide']", /Add a size guide/
    assert_select "th", "Margin"
    assert_select "th", { text: "Track stock", count: 0 }, "Printify's products aren't counted"

    patch shop_admin_product_path(product), params: { product: { status: "active", size_guide: "Size | Chest\nS | 18" } }
    assert product.reload.active?
    assert_empty product.launch_problems

    get shop_admin_printify_imports_path
    assert_select "button", "Update"
    assert_select "a[href=?]", edit_shop_admin_product_path(product)
  end

  test "a Printify order turned down for its address opens the editor at the field" do
    sign_in_as users(:cats_staff)
    orders(:paid).update!(fulfillment_error: "Printify answered 400: address_to.region: The region field is invalid")

    get shop_admin_order_path(orders(:paid))
    assert_select "a[href='#order_shipping_region']", /Fix the state/
    assert_select "details[open] input#order_shipping_region.border-red-400[autofocus]"
  end

  test "importing needs Printify connected" do
    sign_in_as users(:cats_staff)
    get shop_admin_printify_imports_path
    assert_redirected_to shop_admin_printify_connection_path
  end

  test "an order that didn't reach Printify can be sent again" do
    printify = connect_fake_printify
    product = Printify::Import.new.call("pf-tee")
    order = orders(:paid)
    order.line_items.first.update!(variant: product.variant_for(%w[ Black S ]))
    order.update!(fulfillment_error: "Address is invalid")
    sign_in_as users(:cats_staff)

    get shop_admin_order_path(order)
    assert_select "p", "Address is invalid"

    post shop_admin_order_fulfillment_path(order)
    assert order.reload.in_production?
    assert_equal 1, printify.orders.size
    follow_redirect!
    assert_select "a[href=?]", order.printify_url
  end
end
