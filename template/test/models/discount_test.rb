require "test_helper"

class DiscountTest < ActiveSupport::TestCase
  setup do
    @cart = Cart.create!
    @cart.add(variants(:tee_black_s), 2) # $48
  end

  test "a code entered in any case comes off the order, and counts a use" do
    assert_nil @cart.apply_discount_code(" welcome10 ")
    order = place

    assert_equal 480, order.discount_cents
    assert_equal "WELCOME10", order.discount_code
    assert_equal 4800 - 480 + order.shipping_cents, order.total_cents
    assert_equal 1, discounts(:welcome).reload.times_used
    assert_nil @cart.reload.discount_code
  end

  test "an amount off needs the minimum order; free shipping takes the shipping off" do
    @cart.items.first.update!(quantity: 1)
    assert_equal :below_minimum, @cart.apply_discount_code("FIVEOFF")

    assert_nil @cart.apply_discount_code("SHIPFREE")
    assert_equal 0, place.shipping_cents
  end

  test "codes that don't exist, have expired, or are used up are refused" do
    assert_equal :unknown, @cart.apply_discount_code("NOPE")

    discounts(:welcome).update!(ends_at: 1.day.ago, starts_at: 2.days.ago)
    assert_equal :expired, @cart.apply_discount_code("WELCOME10")

    discounts(:welcome).update!(ends_at: nil, starts_at: nil, usage_limit: 1, times_used: 1)
    assert_equal :used_up, @cart.apply_discount_code("WELCOME10")
  end

  test "the last use goes to one order only" do
    discounts(:welcome).update!(usage_limit: 1)
    @cart.apply_discount_code("WELCOME10")
    other = Cart.create!
    other.add(variants(:mug))
    other.apply_discount_code("WELCOME10")

    assert place
    checkout = Checkout.new(cart: other, **details)
    assert_equal 0, checkout.discount_cents, "the used-up code no longer applies"
  end

  test "cancelling gives the use back" do
    @cart.apply_discount_code("WELCOME10")
    place.cancel!
    assert_equal 0, discounts(:welcome).reload.times_used
  end

  test "a code is letters and numbers" do
    assert_not Discount.new(code: "TEN %", kind: "percentage", percent_off: 10).valid?
    assert_not Discount.new(code: "TEN", kind: "percentage", percent_off: 0).valid?
  end

  private
    def details
      { email: "robin@example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St", shipping_city: "Austin", shipping_country: "US" }
    end

    def place
      Checkout.new(cart: @cart, **details).place
    end
end
