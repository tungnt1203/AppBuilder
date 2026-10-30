require "test_helper"

class ShopAdmin::CustomersControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_staff) }

  test "lists buyers by email with their orders and what they spent, sorted and searched" do
    ActsAsTenant.with_tenant(shops(:cats)) do
      orders(:paid).dup.tap { |again| again.assign_attributes(token: SecureRandom.base58(32), number: nil, total_cents: 3000, shipping_name: "Lee B.", created_at: 1.minute.from_now) }.save!
    end

    get shop_admin_customers_path(sort: "spent")
    assert_response :success
    rows = css_select("ul li a").map { |row| row.text.squish }
    assert_match(/Lee B\. lee@example\.com .*\$50\.00/, rows.first, "two paid orders, the latest name")
    assert(rows.any? { |row| row.include?("pat@example.com") && row.include?("$0.00") }, "an unpaid order counts as an order, not as spent")

    get shop_admin_customers_path(q: "sam@")
    assert_select "ul li a", count: 1
    assert_select "ul li a", /Sam Buyer/
  end

  test "a buyer's page has their orders, by one of their orders' tokens" do
    get shop_admin_customer_path(orders(:shipped).token)
    assert_response :success
    assert_select "h1", "Sam Buyer"
    assert_select "a[href=?]", shop_admin_order_path(orders(:shipped))
    assert_select "a[href=?]", "mailto:sam@example.com"
  end

  test "the list as a spreadsheet, with no formulas from what buyers typed" do
    orders(:shipped).update_columns(shipping_name: "=HYPERLINK(1)")

    get shop_admin_customers_path(format: :csv)
    assert_equal "text/csv", response.media_type
    rows = CSV.parse(response.body)
    assert_equal [ "Name", "Email", "Orders", "Spent (USD)", "First order", "Last order" ], rows.first
    assert_includes rows, [ "'=HYPERLINK(1)", "sam@example.com", "1", "48.00", Date.current.iso8601, Date.current.iso8601 ]
  end

  test "orders as a spreadsheet, as filtered" do
    get shop_admin_orders_path(format: :csv, filter: "to_ship")
    rows = CSV.parse(response.body)
    assert_equal %w[ Order Date Status ], rows.first.first(3)
    assert_equal [ "#1002" ], rows.drop(1).map(&:first)
    assert_equal "1 × Morning Mug", rows.second[11]
  end
end
