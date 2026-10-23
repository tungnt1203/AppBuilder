require "test_helper"

class BuyerInputsTest < ActiveSupport::TestCase
  ROW = { "label" => "Name on the shirt", "max_length" => "14",
          "preview" => { "x" => "0.3", "y" => "0.6", "w" => "0.9", "h" => "0.1", "images" => [ "11", "x", "11" ], "font" => "Montserrat",
                         "fonts" => [ "Montserrat", "Lora", "Comic Sans" ], "color" => "#FFFFFF", "colors" => "#ffffff, #f2c45a, red", "align" => "middle", "uppercase" => "1" } }.freeze

  test "a preview keeps the box on the photo, known fonts and colors, and what the buyer may pick" do
    field = BuyerInputs.definitions([ ROW ]).sole
    assert_equal({ "x" => 0.3, "y" => 0.6, "w" => 0.7, "h" => 0.1, "images" => [ 11 ], "font" => "Montserrat", "fonts" => [ "Montserrat", "Lora" ],
                   "color" => "#ffffff", "colors" => [ "#ffffff", "#f2c45a" ], "align" => "center", "uppercase" => true, "curve" => 0, "style" => "plain" }, field["preview"])
  end

  test "no box drawn, no preview; a single font or color is no choice" do
    assert_nil BuyerInputs.definitions([ ROW.merge("preview" => { "x" => "0.2", "w" => "0" }) ]).sole["preview"]

    preview = BuyerInputs.definitions([ ROW.merge("preview" => ROW["preview"].merge("fonts" => [ "Lora" ], "colors" => "#000000")) ]).sole["preview"]
    assert_equal [ [], [] ], preview.values_at("fonts", "colors")
  end

  test "what the buyer picks comes with what they typed, when the shop offers it" do
    fields = BuyerInputs.definitions([ ROW ])
    properties, errors = BuyerInputs.accept(fields, "name_on_the_shirt" => "Grandpa Joe", "name_on_the_shirt_font" => "Lora", "name_on_the_shirt_color" => "#F2C45A")
    assert_nil errors
    assert_equal({ "name_on_the_shirt" => "Grandpa Joe", "name_on_the_shirt_font" => "Lora", "name_on_the_shirt_color" => "#f2c45a" }, properties)

    properties, = BuyerInputs.accept(fields, "name_on_the_shirt" => "Joe", "name_on_the_shirt_font" => "Comic Sans", "name_on_the_shirt_color" => "#123456")
    assert_equal({ "name_on_the_shirt" => "Joe" }, properties)
  end

  test "a line's text on the photo, in the buyer's picks or the shop's defaults" do
    fields = BuyerInputs.definitions([ ROW, { "label" => "Date" } ])
    layer = BuyerInputs.layers(fields, "name_on_the_shirt" => "Joe", "name_on_the_shirt_font" => "Lora", "date" => "1970").sole
    assert_equal [ "text", "Joe", "Lora", "#ffffff", [ 11 ], true ], layer.values_at("kind", "text", "font", "color", "images", "uppercase")
    assert_empty BuyerInputs.layers(fields, "date" => "1970")
  end

  test "a photo's framing stays within what can be printed" do
    assert_equal [ 1.5, 0.4, 1.0 ], BuyerInputs.crop("1.5,0.4,9")
    assert_equal [ 4, 0.5, 0.5 ], BuyerInputs.crop("12")
    assert_equal [ 1, 0.5, 0.5 ], BuyerInputs.crop("junk")
  end

  test "a photo field keeps a box and photos, and lines name the photo without its token" do
    in_shop
    field = BuyerInputs.definitions([ { "label" => "Your photo", "kind" => "photo", "max_length" => "9", "preview" => { "x" => "0.1", "y" => "0.1", "w" => "0.5", "h" => "0.5", "font" => "Lora" } } ]).sole
    assert_equal [ "photo", nil, { "x" => 0.1, "y" => 0.1, "w" => 0.5, "h" => 0.5, "images" => [], "filters" => [] } ], field.values_at("kind", "max_length", "preview")

    upload = BuyerUpload.take(Rack::Test::UploadedFile.new(file_fixture("product.png"), "image/png"))
    properties, = BuyerInputs.accept([ field ], "your_photo" => upload.token, "your_photo_crop" => "2,0.3,0.6")
    assert_equal({ "your_photo" => upload.token, "your_photo_crop" => "2.0,0.3,0.6" }, properties)

    product = products(:tee).tap { |tee| tee.update!(buyer_inputs: [ field ]) }
    item = LineItem.new(product_title: product.title, variant: product.variants.first, properties:)
    assert_equal [ "Your photo: Added" ], item.property_lines
    assert_equal [ [ "Your photo", upload, [ 2.0, 0.3, 0.6 ] ] ], item.buyer_photos.map { |photo| photo.values_at(:label, :upload, :crop) }
  end

  test "a photo too small for its box's print size, as the buyer zoomed it, is flagged for staff" do
    in_shop
    upload = BuyerUpload.take(Rack::Test::UploadedFile.new(file_fixture("product.png"), "image/png")) # 40 × 50
    assert upload.sharp_for?(nil), "nothing to tell without the print size"
    assert upload.sharp_for?([ 80, 100 ])
    assert_not upload.sharp_for?([ 80, 100 ], 1.5), "zoomed in, less of it fills the box"
    assert_not upload.sharp_for?([ 300, 300 ])

    field = { "key" => "photo", "label" => "Photo", "kind" => "photo", "preview" => { "x" => 0.3, "y" => 0.3, "w" => 0.2, "h" => 0.2 } }
    product = products(:tee).tap { |tee| tee.update!(buyer_inputs: [ field ], print_areas: { "front" => { "x" => 0.2, "y" => 0.2, "w" => 0.4, "h" => 0.4, "pixels" => [ 160, 200 ] } }) }
    assert_equal [ 80, 100 ], product.print_pixels(product.buyer_inputs.sole)
    item = LineItem.new(product_title: product.title, variant: product.variants.first, properties: { "photo" => upload.token, "photo_crop" => "1,0.5,0.5" })
    assert item.buyer_photos.sole[:sharp]
    item.properties["photo_crop"] = "2,0.5,0.5"
    assert_not item.buyer_photos.sole[:sharp]
  end

  test "what the buyer added reads well on a line: looks, days and cities in words, no framing" do
    fields = [ { "key" => "name", "label" => "Name", "kind" => "text" }, { "key" => "photo", "label" => "Photo", "kind" => "photo" },
               { "key" => "night", "label" => "Our night", "kind" => "starmap" }, { "key" => "fav_color", "label" => "Favorite color", "kind" => "text" } ]
    entries = BuyerInputs.entries(fields, { "name" => "Ada", "name_font" => "Lora", "name_color" => "#f2c45a", "photo" => "upl_x", "photo_crop" => "1,0.5,0.5",
      "photo_filter" => "bw", "night" => "2020-02-14", "night_place" => "hanoi-vietnam", "fav_color" => "teal", "gift_note" => "Hi" })
    assert_equal [ [ "Name", "Ada" ], [ "Name font", "Lora" ], [ "Name color", "#f2c45a" ], [ "Photo", "Added" ], [ "Photo look", "Black and white" ],
      [ "Our night", "February 14, 2020" ], [ "Our night city", "Hanoi, Vietnam" ], [ "Favorite color", "teal" ], [ "Gift note", "Hi" ] ], entries.map { |entry| entry.values_at(:label, :value) }
    assert_equal [ "text", nil, nil, "photo" ], entries.first(4).pluck(:kind)
    assert_equal "upl_x", entries[3][:raw]
  end

  test "a photo box drawn with a layout becomes a photo field per cell, with gaps between them" do
    fields = BuyerInputs.definitions([ { "label" => "Photo", "kind" => "photo", "layout" => "2x1", "preview" => { "x" => "0.1", "y" => "0.2", "w" => "0.6", "h" => "0.3", "images" => [ "5" ] } } ])
    assert_equal [ "photo_1", "photo_2" ], fields.pluck("key")
    assert_equal [ "Photo 1", "Photo 2" ], fields.pluck("label")
    first, second = fields.pluck("preview")
    assert_equal [ 0.1, 0.2, 0.291, 0.3, [ 5 ] ], first.values_at("x", "y", "w", "h", "images")
    assert_in_delta 0.409, second["x"], 0.001
    assert_nil fields.first["layout"]
  end

  test "a picture and a color are picked from what the shop offers, and show on the line's photo" do
    fields = BuyerInputs.definitions([
      { "label" => "Background", "kind" => "color", "preview" => { "x" => "0", "y" => "0", "w" => "1", "h" => "1", "colors" => "#FFEEDD, #112233" } },
      { "label" => "Breed", "kind" => "choice", "options" => [ "7", "9" ], "preview" => { "x" => "0.3", "y" => "0.3", "w" => "0.4", "h" => "0.4" } }
    ])
    assert_equal [ "#ffeedd", "#112233" ], fields.first.dig("preview", "colors")
    assert_equal [ 7, 9 ], fields.second["options"]

    _, errors = BuyerInputs.accept(fields, "background" => "#000000", "breed" => "8")
    assert_equal({ "background" => "isn't one of the colors", "breed" => "isn't one of the choices" }, errors)

    properties, = BuyerInputs.accept(fields, "background" => "#112233", "breed" => "9")
    assert_equal [ [ "color", "#112233" ], [ "choice", 9 ] ], BuyerInputs.layers(fields, properties).map { |layer| layer.values_at("kind", "color").compact + layer.values_at("artwork").compact }
  end

  test "a monogram takes one to three letters, in capitals; a photo's look is one the shop offers" do
    fields = BuyerInputs.definitions([
      { "label" => "Initials", "preview" => { "x" => "0.1", "y" => "0.1", "w" => "0.3", "h" => "0.2", "style" => "monogram", "curve" => "500" } },
      { "label" => "Photo", "kind" => "photo", "preview" => { "x" => "0.5", "y" => "0.1", "w" => "0.3", "h" => "0.3", "filters" => [ "sepia", "bw", "neon" ] } }
    ])
    assert_equal [ "monogram", 180 ], fields.first["preview"].values_at("style", "curve")
    assert_equal [ "bw", "sepia" ], fields.second.dig("preview", "filters")

    _, errors = BuyerInputs.accept(fields, "initials" => "1 2")
    assert_equal "needs one to three letters", errors["initials"]
    in_shop
    upload = BuyerUpload.take(Rack::Test::UploadedFile.new(file_fixture("product.png"), "image/png"))
    properties, = BuyerInputs.accept(fields, "initials" => "j.d.s", "photo" => upload.token, "photo_filter" => "sepia")
    assert_equal [ "JDS", "sepia" ], properties.values_at("initials", "photo_filter")
    assert_equal "sepia", BuyerInputs.layers(fields, properties).second["filter"]
  end

  test "a star map takes a day and one of the cities, and the lines can be hidden" do
    field = BuyerInputs.definitions([ { "label" => "Our night", "kind" => "starmap", "preview" => { "x" => "0.2", "y" => "0.2", "w" => "0.5", "h" => "0.5", "sky" => "#000000", "no_lines" => "1" } } ]).sole
    assert_equal [ "#000000", "#ffffff", false ], field["preview"].values_at("sky", "ink", "lines")

    _, errors = BuyerInputs.accept([ field ], "our_night" => "2020-02-14", "our_night_place" => "atlantis")
    assert_equal "needs a date and one of the places", errors["our_night"]
    properties, = BuyerInputs.accept([ field ], "our_night" => "2020-02-14T21:30", "our_night_place" => "hanoi-vietnam")
    assert_equal [ "starmap", "2020-02-14T21:30", "hanoi-vietnam", false ], BuyerInputs.layers([ field ], properties).sole.values_at("kind", "when", "place", "lines")
  end
end
