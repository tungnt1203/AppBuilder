require "test_helper"

class CheckoutTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @cart = Cart.create!
    @cart.add(variants(:tee_black_s), 2)
    @cart.add(variants(:mug))
  end

  test "places an order with the cart's items at today's prices, plus shipping, and empties the cart" do
    order = checkout.place

    assert order.persisted?
    assert order.pending?
    assert_equal 2400 * 2 + 1500, order.subtotal_cents
    assert_equal 500 + 200 * 2, order.shipping_cents
    assert_equal order.subtotal_cents + order.shipping_cents, order.total_cents
    assert_equal [ [ "Cat Mom Tee", "Black / S", 2400, 2 ], [ "Morning Mug", nil, 1500, 1 ] ],
      order.line_items.map { |line| [ line.product_title, line.variant_title, line.unit_price_cents, line.quantity ] }
    assert_equal "USD", order.currency
    assert_equal [ "placed" ], order.events.map(&:action)
    assert_empty @cart.items.reload
  end

  test "emails the buyer and the owner" do
    assert_enqueued_emails 2 do
      checkout.place
    end
  end

  test "numbers orders after the last one" do
    assert_equal 1004, checkout.place.number
  end

  test "a price change after adding to the cart is what the buyer pays" do
    variants(:mug).update!(price_cents: 1000)
    assert_equal 2400 * 2 + 1000, checkout.place.subtotal_cents
  end

  test "needs contact and address" do
    result = checkout(email: "", shipping_address1: "").place

    assert_nil result
    assert checkout(email: "").tap(&:valid?).errors.include?(:email)
    assert_equal 0, Order.where(email: "").count
  end

  test "only ships to the store's countries" do
    placing = checkout(shipping_country: "VN")

    assert_nil placing.place
    assert placing.errors.added?(:shipping_country, :not_shipped_to)
  end

  test "an empty cart can't be checked out" do
    placing = Checkout.new(cart: Cart.create!, **details)

    assert_nil placing.place
    assert placing.errors.added?(:base, :empty_cart)
  end

  test "items that can't be bought are left out" do
    @cart.add(variants(:hoodie))
    assert_equal 2, checkout.place.line_items.size
  end

  private
    def details
      { email: "Robin@Example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St",
        shipping_city: "Austin", shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US" }
    end

    def checkout(**overrides)
      Checkout.new(cart: @cart, **details.merge(overrides))
    end

  test "an email needs a full domain, as Stripe and mail servers require" do
    checkout = Checkout.new(cart: Cart.create!, email: "tung@gmail")
    checkout.validate
    assert checkout.errors.of_kind?(:email, :invalid)

    checkout.email = "tung@gmail.com"
    checkout.validate
    assert_not checkout.errors.include?(:email)
  end
end
