require "test_helper"

class CartDiscountsControllerTest < ActionDispatch::IntegrationTest
  test "a buyer applies a code in the cart, sees it at checkout, and removes it" do
    post cart_items_path, params: { variant_id: variants(:tee_black_s).id, quantity: 2 }

    post cart_discount_path, params: { code: "welcome10" }
    assert_redirected_to cart_path
    follow_redirect!
    assert_select "span", "WELCOME10"

    get new_checkout_path
    assert_match "Discount (WELCOME10)", response.body

    delete cart_discount_path
    get cart_path
    assert_select "input[name=code]"
  end

  test "a wrong code says why" do
    post cart_items_path, params: { variant_id: variants(:mug).id }
    post cart_discount_path, params: { code: "NOPE" }
    assert_equal "That code doesn't exist", flash[:alert]
  end
end
