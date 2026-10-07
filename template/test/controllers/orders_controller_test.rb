require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "the buyer opens their order by its link" do
    get order_path(orders(:pending))

    assert_response :success
    assert_select "h1", /1001/
    assert_match "bank transfer", response.body
  end

  test "an order can't be found by its id or number" do
    get "/orders/#{orders(:pending).id}"
    assert_response :not_found

    get "/orders/1001"
    assert_response :not_found
  end

  test "shows tracking once shipped" do
    get order_path(orders(:shipped))
    assert_match "9400100000000000000000", response.body
  end
end
