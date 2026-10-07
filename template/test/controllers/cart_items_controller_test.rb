require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  test "adding to the cart makes one and shows it" do
    assert_difference -> { Cart.count } do
      post cart_items_path, params: { variant_id: variants(:tee_black_m).id, quantity: 2 }
    end

    assert_redirected_to cart_path
    follow_redirect!
    assert_select "##{dom_id(Cart.last.items.first)}", /Black \/ M/
    assert_select "#cart-link", /2/
  end

  test "can't add what isn't for sale" do
    post cart_items_path, params: { variant_id: variants(:tee_white_s).id }
    assert_equal 0, Cart.count

    post cart_items_path, params: { variant_id: variants(:hoodie).id }
    assert_equal 0, Cart.count
  end

  test "changing the quantity, to zero removes it" do
    post cart_items_path, params: { variant_id: variants(:mug).id }
    item = Cart.last.items.first

    patch cart_item_path(item), params: { quantity: 4 }
    assert_equal 4, item.reload.quantity

    patch cart_item_path(item), params: { quantity: 0 }
    assert_not CartItem.exists?(item.id)
  end

  test "removing" do
    post cart_items_path, params: { variant_id: variants(:mug).id }
    delete cart_item_path(Cart.last.items.first)

    assert_redirected_to cart_path
    assert_empty Cart.last.items
  end

  test "someone else's cart items are out of reach" do
    other = Cart.create!.tap { |cart| cart.add(variants(:mug)) }.items.first

    post cart_items_path, params: { variant_id: variants(:tee_black_s).id }
    delete cart_item_path(other)

    assert_response :not_found
    assert CartItem.exists?(other.id)
  end
end
