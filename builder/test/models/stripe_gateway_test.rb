require "test_helper"

class StripeGatewayTest < ActiveSupport::TestCase
  setup { in_shop }

  test "a PaymentIntent for the order's total, once per order, with its address" do
    order = orders(:pending)
    sent = {}
    replacing(Stripe::PaymentIntent, :create, ->(params, options) { sent.merge!(params:, options:); Struct.new(:id, :client_secret).new("pi_1", "pi_1_secret") }) do
      assert_equal({ id: "pi_1", client_secret: "pi_1_secret" }, StripeGateway.new("sk_test_1").create_payment_intent(order, tax_calculation: "taxcalc_1"))
    end

    assert_equal [ 2900, "usd", "pat@example.com" ], sent[:params].values_at(:amount, :currency, :receipt_email)
    assert_equal({ order_id: order.id, order_number: 1001, shop: "cats01", tax_calculation: "taxcalc_1" }, sent[:params][:metadata])
    assert_equal({ line1: "1 Main St", city: "Portland", state: "OR", postal_code: "97201", country: "US" }, sent[:params][:shipping][:address])
    assert_equal "order-cats01-#{order.id}", sent[:options][:idempotency_key]
  end

  test "Stripe Tax gets each line after its share of the discount, and shipping" do
    order = orders(:pending)
    order.update!(discount_cents: 480)
    sent = {}
    replacing(Stripe::Tax::Calculation, :create, ->(params, _options) { sent = params; Struct.new(:id, :tax_amount_exclusive).new("taxcalc_1", 192) }) do
      assert_equal({ id: "taxcalc_1", tax_cents: 192 }, StripeGateway.new("sk_test_1").tax_calculation(order))
    end
    assert_equal order.line_items.sum { |item| item.unit_price_cents * item.quantity } - 480, sent[:line_items].sum { |line| line[:amount] }
    assert_equal({ amount: 500, tax_behavior: "exclusive" }, sent[:shipping_cost])
    assert_equal "shipping", sent[:customer_details][:address_source]
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
