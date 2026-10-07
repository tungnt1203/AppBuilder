require "test_helper"

class MoneyHelperTest < ActionView::TestCase
  test "formats cents in the shop's currency" do
    assert_equal "$24.00", money(2400)
    assert_equal "€24.50", money(2450, "EUR")
    assert_equal "150,000 ₫", money(15_000_000, "VND")
  end

  test "shows a range when variants differ" do
    assert_equal "$24.00 – $26.00", price_range(products(:tee))
    assert_equal "$15.00", price_range(products(:mug))
  end
end
