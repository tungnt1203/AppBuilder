require "test_helper"

class CartTest < ActiveSupport::TestCase
  setup { in_shop }

  test "adding the same variant again adds to its quantity, up to the limit" do
    cart = Cart.create!
    cart.add(variants(:mug), 2)
    cart.add(variants(:mug), 3)

    assert_equal 1, cart.items.count
    assert_equal 5, cart.item_count

    cart.add(variants(:mug), 500)
    assert_equal Cart::MAX_QUANTITY, cart.items.first.quantity
  end

  test "lines of the same variant share its stock" do
    variants(:mug).update!(track_inventory: true, inventory_quantity: 3)
    cart = Cart.create!
    first = cart.add(variants(:mug), 3, properties: { "print_name" => "Ada" })
    cart.add(variants(:mug), 3, properties: { "print_name" => "Bob" })

    assert_equal 1, cart.items.count
    assert_equal 3, cart.item_count

    cart.update_quantity(first, 1)
    cart.add(variants(:mug), 3, properties: { "print_name" => "Bob" })
    assert_equal [ 1, 2 ], cart.items.map(&:quantity)

    cart.update_quantity(first, 5)
    assert_equal 1, first.reload.quantity
  end

  test "items that can't be bought any more are left out of the subtotal" do
    cart = Cart.create!
    cart.add(variants(:mug), 2)
    cart.add(variants(:hoodie))

    assert_equal [ variants(:mug) ], cart.buyable_items.map(&:variant)
    assert_equal 3000, cart.subtotal_cents
  end
end
