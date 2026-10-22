class AddPrintAreaToProducts < ActiveRecord::Migration[8.1]
  def change
    # Where Printify's print area sits on one of the product's photos (x, y, w, h as fractions of it)
    # and which one it is ("front"): what the buyer adds is placed on the print file from there.
    add_column :products, :print_area, :jsonb, null: false, default: {}
  end
end
