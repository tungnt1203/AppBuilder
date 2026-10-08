require "test_helper"

class PromotionTest < ActiveSupport::TestCase
  setup do
    @variant = variants(:tee_black_s) # $24, no compare-at
  end

  def sale(**attributes)
    Promotion.create!(name: "Summer", percent_off: 25, starts_at: 1.hour.ago, ends_at: 1.day.from_now, variant_ids: [ @variant.id ], **attributes)
  end

  test "starts on time: the sale price, with the old one shown as compare-at" do
    promotion = sale
    Promotion::SyncJob.perform_now

    assert promotion.reload.active?
    assert_equal 1800, @variant.reload.price_cents
    assert_equal 2400, @variant.compare_at_price_cents
  end

  test "ends on time and puts the prices back" do
    promotion = sale
    Promotion::SyncJob.perform_now
    Promotion::SyncJob.perform_now(2.days.from_now)

    assert promotion.reload.ended?
    assert_equal 2400, @variant.reload.price_cents
    assert_nil @variant.compare_at_price_cents
  end

  test "a price staff changed during the sale is kept" do
    promotion = sale
    promotion.start!
    @variant.update!(price_cents: 2000)
    promotion.finish!
    assert_equal 2000, @variant.reload.price_cents
  end

  test "a sale that hasn't started yet doesn't touch prices; cancelling it is safe" do
    promotion = sale(starts_at: 1.day.from_now, ends_at: 2.days.from_now)
    Promotion::SyncJob.perform_now
    assert promotion.reload.scheduled?
    promotion.cancel!
    assert promotion.cancelled?
    assert_equal 2400, @variant.reload.price_cents
  end

  test "a variant can't be in two sales at once" do
    sale
    overlapping = Promotion.new(name: "Flash", percent_off: 10, starts_at: 2.hours.from_now, ends_at: 3.hours.from_now, variant_ids: [ @variant.id ])
    assert_not overlapping.valid?
    assert overlapping.errors.added?(:base, :overlaps, product: "Cat Mom Tee")
  end
end
