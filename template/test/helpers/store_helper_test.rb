require "test_helper"

class StoreHelperTest < ActionView::TestCase
  test "swatches come from the product's own colors first, then known color names" do
    product = products(:tee)
    product.update!(option_colors: { "Sport Grey" => "#9b9b9b" })

    assert_equal "#9b9b9b", swatch_color("Sport Grey", product)
    assert_nil swatch_color("Sport Grey")
    assert swatch_color("Black", product)
    assert_nil swatch_color("Vintage wash", product)
  end
end
