require "test_helper"

class BuyerInputsTest < ActiveSupport::TestCase
  ROW = { "label" => "Name on the shirt", "max_length" => "14",
          "preview" => { "x" => "0.3", "y" => "0.6", "w" => "0.9", "h" => "0.1", "images" => [ "11", "x", "11" ], "font" => "Montserrat",
                         "fonts" => [ "Montserrat", "Lora", "Comic Sans" ], "color" => "#FFFFFF", "colors" => "#ffffff, #f2c45a, red", "align" => "middle", "uppercase" => "1" } }.freeze

  test "a preview keeps the box on the photo, known fonts and colors, and what the buyer may pick" do
    field = BuyerInputs.definitions([ ROW ]).sole
    assert_equal({ "x" => 0.3, "y" => 0.6, "w" => 0.7, "h" => 0.1, "images" => [ 11 ], "font" => "Montserrat", "fonts" => [ "Montserrat", "Lora" ],
                   "color" => "#ffffff", "colors" => [ "#ffffff", "#f2c45a" ], "align" => "center", "uppercase" => true }, field["preview"])
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
    assert_equal [ "Joe", "Lora", "#ffffff", [ 11 ], true ], layer.values_at("text", "font", "color", "images", "uppercase")
    assert_empty BuyerInputs.layers(fields, "date" => "1970")
  end
end
