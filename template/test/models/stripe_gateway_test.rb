require "test_helper"

class StripeGatewayTest < ActiveSupport::TestCase
  test "the checkout carries the discount as a one-off coupon, Stripe Tax when on, and expires in an hour" do
    order = orders(:pending)
    order.update!(discount_cents: 480, discount_code: "WELCOME10")
    sent = {}
    session = Struct.new(:id, :url).new("cs_1", "https://checkout.stripe.com/cs_1")

    replacing(Stripe::Coupon, :create, ->(params, _options) { sent[:coupon] = params; Struct.new(:id).new("co_1") }) do
      replacing(Stripe::Checkout::Session, :create, ->(params, _options) { sent[:session] = params; session }) do
        assert_equal [ "cs_1", session.url ], StripeGateway.new("sk_test_1").create_checkout(order, success_url: "s", cancel_url: "c", tax: true)
      end
    end

    assert_equal({ amount_off: 480, currency: "usd", duration: "once", max_redemptions: 1, name: "WELCOME10" }, sent[:coupon])
    assert_equal [ { coupon: "co_1" } ], sent[:session][:discounts]
    assert_equal({ enabled: true }, sent[:session][:automatic_tax])
    assert_in_delta 1.hour.from_now.to_i, sent[:session][:expires_at], 5
  end

  test "zero-decimal currencies go to Stripe in whole units and come back as hundredths" do
    assert_equal 50_000, StripeGateway.amount(5_000_000, "VND")
    assert_equal 5_000_000, StripeGateway.cents(50_000, "VND")
    assert_equal 1999, StripeGateway.cents(1999, "USD")
  end

  private
    # Stands in for a Stripe API call during the block, so nothing reaches the network.
    def replacing(klass, method, fake)
      original = klass.method(method)
      klass.define_singleton_method(method, &fake)
      yield
    ensure
      klass.define_singleton_method(method, original)
    end
end
