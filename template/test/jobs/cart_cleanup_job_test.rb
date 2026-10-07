require "test_helper"

class Cart::CleanupJobTest < ActiveJob::TestCase
  test "clears carts untouched for 30 days and keeps the rest" do
    old = Cart.create!.tap { |cart| cart.add(variants(:mug)) }
    old.update_columns(updated_at: 31.days.ago)
    fresh = Cart.create!.tap { |cart| cart.add(variants(:mug)) }

    Cart::CleanupJob.perform_now

    assert_not Cart.exists?(old.id)
    assert Cart.exists?(fresh.id)
    assert_equal 1, CartItem.count
  end
end
