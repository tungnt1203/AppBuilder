require "test_helper"

class Personalization::PrintFileTest < ActiveSupport::TestCase
  setup do
    in_shop
    @product = products(:tee)
    @product.update!(print_area: { "x" => 0.2, "y" => 0.2, "w" => 0.6, "h" => 0.6 }, buyer_inputs: [
      { "label" => "Background", "kind" => "color", "preview" => { "x" => 0.2, "y" => 0.2, "w" => 0.3, "h" => 0.3, "colors" => "#ff0000, #0000ff" } },
      { "label" => "Name", "preview" => { "x" => 0.2, "y" => 0.65, "w" => 0.6, "h" => 0.15, "font" => "Pacifico", "color" => "#00ff00" } }
    ])
  end

  test "what the buyer added is drawn where it sits on the print area, the rest left clear" do
    file = Personalization::PrintFile.new(@product, { "background" => "#0000ff", "name" => "Ada" })
    assert file.printable?

    image = Vips::Image.new_from_buffer(file.render(width: 600, height: 600), "")
    assert_equal [ 600, 600, 4 ], [ image.width, image.height, image.bands ]
    assert_equal [ 0, 0, 255, 255 ], image.getpoint(100, 100).map(&:round), "the color's box: the print area's top left half"
    assert_equal 0, image.getpoint(450, 150)[3], "nothing there"
    name = image.crop(0, 450, 600, 150).extract_band(3)
    assert name.max.positive?, "the name is drawn in its box"
    assert_equal 0, image.crop(0, 310, 600, 130).extract_band(3).max, "and only there"
  end

  test "nothing to print without a print area, or with nothing added" do
    assert_not Personalization::PrintFile.new(@product, {}).printable?
    @product.update!(print_area: {})
    assert_not Personalization::PrintFile.new(@product, { "name" => "Ada" }).printable?
  end

  test "a buyer's words are only words to ImageMagick" do
    assert_equal '\@/etc/passwd 100%% \\\\n', Personalization::PrintFile.escape("@/etc/passwd 100% \\n")
  end

  test "a sample shows each field's label, a gray box for a photo, the first color" do
    @product.update!(buyer_inputs: @product.buyer_inputs + [ { "label" => "Photo", "kind" => "photo", "preview" => { "x" => 0.5, "y" => 0.2, "w" => 0.3, "h" => 0.3 } } ])
    sample = Personalization::PrintFile.sample(@product)
    assert_equal [ "color", "text", "photo" ], sample.layers.pluck("kind")

    image = Vips::Image.new_from_buffer(sample.render(width: 600, height: 600), "")
    assert_equal [ 255, 0, 0, 255 ], image.getpoint(100, 100).map(&:round)
    assert_equal [ 209, 213, 219, 255 ], image.getpoint(450, 100).map(&:round)
  end
end
