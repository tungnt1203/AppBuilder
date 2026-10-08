require "test_helper"

class InventoryTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @variant = variants(:tee_black_s)
    @variant.update!(track_inventory: true, inventory_quantity: 3)
  end

  test "untracked variants never run out" do
    mug = variants(:mug)
    assert mug.in_stock?
    assert mug.take_stock(500)
    assert_equal 0, mug.reload.inventory_quantity
  end

  test "the cart never asks for more than is in stock" do
    cart = Cart.create!
    item = cart.add(@variant, 10)
    assert_equal 3, item.quantity

    cart.update_quantity(item, 7)
    assert_equal 3, item.reload.quantity
  end

  test "placing the order takes the stock; cancelling gives it back" do
    cart = Cart.create!
    cart.add(@variant, 2)
    order = place(cart)

    assert_equal 1, @variant.reload.inventory_quantity
    order.cancel!
    assert_equal 3, @variant.reload.inventory_quantity
  end

  test "an order for more than is left is refused, and nothing is taken" do
    cart = Cart.create!
    cart.add(@variant, 3)
    cart.add(variants(:mug))
    @variant.update!(inventory_quantity: 1)

    checkout = Checkout.new(cart:, **details)
    assert_no_difference -> { Order.count } do
      assert_nil checkout.place
    end
    assert checkout.errors.added?(:base, :out_of_stock, product: "Cat Mom Tee – Black / S", count: 1)
    assert_equal 1, @variant.reload.inventory_quantity
  end

  test "a sold-out variant can't be bought, and a product with none left is sold out" do
    @variant.update!(inventory_quantity: 0)
    assert_not @variant.buyable?

    products(:mug).variants.each { |variant| variant.update!(track_inventory: true, inventory_quantity: 0) }
    assert_not products(:mug).reload.available?
  end

  private
    def details
      { email: "robin@example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St", shipping_city: "Austin", shipping_country: "US" }
    end

    def place(cart)
      Checkout.new(cart:, **details).place
    end
end
