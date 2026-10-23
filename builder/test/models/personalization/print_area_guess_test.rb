require "test_helper"

class Personalization::PrintAreaGuessTest < ActiveSupport::TestCase
  setup do
    in_shop
    @printify = connect_fake_printify
    # The design: 400 × 200, its ink the middle half; in the print area (300 × 400 in the fake
    # catalog) 0.8 of its width, centered at (0.5, 0.3).
    design = Vips::Image.black(400, 200, bands: 4).copy(interpretation: :srgb).draw_rect([ 0, 0, 0, 255 ], 100, 50, 200, 100, fill: true)
    @printify.product_data["print_areas"].first["placeholders"] = [
      { "position" => "front", "images" => [ { "id" => "d", "type" => "image/png", "src" => "https://images.example/design.png", "x" => 0.5, "y" => 0.3, "scale" => 0.8, "angle" => 0 } ] }
    ]
    @printify.define_singleton_method(:download) { |_url| StringIO.new(design.write_to_buffer(".png")) }
    @product = products(:tee).tap { |tee| tee.update!(printify_product_id: "pf-tee") }
  end

  test "the print area is found on the photo from where the design's ink shows on it" do
    # A plain shirt photo whose print area is x 0.3, y 0.25, w 0.4 (h 0.5333): the ink lands at 252, 222, 96 × 48.
    photo = Vips::Image.black(600, 600).new_from_image([ 248, 248, 248 ]).copy(interpretation: :srgb).draw_rect([ 20, 20, 20 ], 252, 222, 96, 48, fill: true)
    @product.images.attach(io: StringIO.new(photo.write_to_buffer(".jpg")), filename: "front.jpg", content_type: "image/jpeg")

    found = Personalization::PrintAreaGuess.new(@product, gateway: @printify, shop_id: 4242).call
    { "x" => 0.3, "y" => 0.25, "w" => 0.4, "h" => 0.5333 }.each { |side, value| assert_in_delta value, found[side], 0.01, side }
    assert_equal [ 300, 400 ], found["pixels"], "Printify's print area in pixels"
  end

  test "the back's is found on the photo of the back, Printify's mockup of it" do
    @printify.product_data["print_areas"].first["placeholders"] << @printify.product_data["print_areas"].first["placeholders"].first.merge("position" => "back")
    blank = Vips::Image.black(600, 600).new_from_image([ 248, 248, 248 ]).copy(interpretation: :srgb)
    back = blank.draw_rect([ 20, 20, 20 ], 252, 222, 96, 48, fill: true)
    @product.images.attach(io: StringIO.new(blank.write_to_buffer(".jpg")), filename: "front.jpg", content_type: "image/jpeg", metadata: { printify_src: "https://images.example/black-front.jpg" })
    assert_nil Personalization::PrintAreaGuess.new(@product, gateway: @printify, shop_id: 4242).call(position: "back"), "no photo of the back"

    @product.images.attach(io: StringIO.new(back.write_to_buffer(".jpg")), filename: "back.jpg", content_type: "image/jpeg", metadata: { printify_src: "https://images.example/black-back.jpg" })
    found = Personalization::PrintAreaGuess.new(@product, gateway: @printify, shop_id: 4242).call(position: "back")
    assert_in_delta 0.3, found["x"], 0.01
  end

  test "nothing when the design can't be told apart on the photo" do
    blank = Vips::Image.black(600, 600).new_from_image([ 248, 248, 248 ]).copy(interpretation: :srgb)
    @product.images.attach(io: StringIO.new(blank.write_to_buffer(".jpg")), filename: "front.jpg", content_type: "image/jpeg")
    assert_nil Personalization::PrintAreaGuess.new(@product, gateway: @printify, shop_id: 4242).call
  end
end
