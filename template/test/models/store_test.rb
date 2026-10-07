require "test_helper"

class StoreTest < ActiveSupport::TestCase
  setup { @store = stores(:main) }

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
end
