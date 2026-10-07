require "test_helper"

class VariantTest < ActiveSupport::TestCase
  test "prices are written as decimals and kept as cents" do
    variant = variants(:mug)
    variant.update!(price: "18.5", compare_at_price: "")

    assert_equal 1850, variant.price_cents
    assert_nil variant.compare_at_price_cents
    assert_equal BigDecimal("18.5"), variant.price
  end

  test "on sale when the compare-at price is higher" do
    assert variants(:tee_black_m).on_sale?
    assert_not variants(:tee_black_s).on_sale?
  end

  test "title joins the option values" do
    assert_equal "Black / S", variants(:tee_black_s).title
  end

  test "buyable only when available and its product is active" do
    assert variants(:tee_black_s).buyable?
    assert_not variants(:tee_white_s).buyable?
    assert_not variants(:hoodie).buyable?
  end

  test "one variant per combination of options" do
    duplicate = products(:tee).variants.build(option1: "Black", option2: "S", price_cents: 100)
    assert_not duplicate.valid?
  end
end
