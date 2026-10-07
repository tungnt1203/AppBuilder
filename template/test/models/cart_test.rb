require "test_helper"

class CartTest < ActiveSupport::TestCase
  test "adding the same variant again adds to its quantity, up to the limit" do
    cart = Cart.create!
    cart.add(variants(:mug), 2)
    cart.add(variants(:mug), 3)

    assert_equal 1, cart.items.count
    assert_equal 5, cart.item_count

    cart.add(variants(:mug), 500)
    assert_equal Cart::MAX_QUANTITY, cart.items.first.quantity
  end

  test "items that can't be bought any more are left out of the subtotal" do
    cart = Cart.create!
    cart.add(variants(:mug), 2)
    cart.add(variants(:hoodie))

    assert_equal [ variants(:mug) ], cart.buyable_items.map(&:variant)
    assert_equal 3000, cart.subtotal_cents
  end
end
