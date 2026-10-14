class AddOptionColorsToProducts < ActiveRecord::Migration[8.1]
  def change
    # The swatch of each color value, from Printify ({"Sport Grey" => "#9b9b9b"}), for colors the
    # product page doesn't know by name.
    add_column :products, :option_colors, :json, null: false, default: {}
  end
end
