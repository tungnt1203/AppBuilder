require "test_helper"

class StoreTest < ActiveSupport::TestCase
  setup { in_shop }

  setup { @store = stores(:cats) }

  test "flat-rate shipping: first item, then each additional one" do
    assert_equal 0, @store.shipping_cents_for(item_count: 0, subtotal_cents: 0)
    assert_equal 500, @store.shipping_cents_for(item_count: 1, subtotal_cents: 2400)
    assert_equal 900, @store.shipping_cents_for(item_count: 3, subtotal_cents: 7200)
  end

  test "free shipping from the threshold" do
    assert_equal 0, @store.shipping_cents_for(item_count: 5, subtotal_cents: 10_000)
  end

  test "ships to its countries, or anywhere when none are set" do
    assert @store.ships_to?("us")
    assert_not @store.ships_to?("VN")

    @store.ship_to_countries = []
    assert @store.ships_to?("VN")
  end

  test "countries are written as codes and must be known" do
    @store.ship_to_countries_text = "us, gb  ca"
    assert_equal %w[ CA GB US ], @store.ship_to_countries

    @store.ship_to_countries_text = "US, XX"
    assert_not @store.valid?
  end

  test "current is the one store, made when missing" do
    assert_equal @store, Store.current

    Store.delete_all
    assert_difference -> { Store.count } do
      Store.current
    end
  end

  test "delivery dates count business days from the order" do
    assert_nil @store.delivery_dates

    @store.update!(delivery_days_min: 3, delivery_days_max: 5)
    friday = Date.new(2026, 10, 16)
    assert_equal [ Date.new(2026, 10, 21), Date.new(2026, 10, 23) ], @store.delivery_dates(from: friday)

    @store.delivery_days_max = 2
    assert_not @store.valid?
  end

  test "what's left to spend for free shipping" do
    assert_equal 2600, @store.free_shipping_remaining_cents(7400)
    assert_nil @store.free_shipping_remaining_cents(10_000)

    @store.free_shipping_threshold_cents = nil
    assert_nil @store.free_shipping_remaining_cents(100)
  end

  test "two first requests at once take the same settings" do
    Store.singleton_class.alias_method :real_first, :first
    Store.define_singleton_method(:first) { nil } # the other request made it after this one looked
    assert_equal @store, Store.current
  ensure
    Store.singleton_class.alias_method :first, :real_first
  end

  test "demo products don't count as the shop's first product on sale" do
    Product.update_all(demo: true)
    assert_not @store.setup_steps[:product]

    Product.first.update_columns(demo: false, status: "active")
    assert @store.setup_steps[:product]
  end
end
