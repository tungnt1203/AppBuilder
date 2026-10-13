class AddSellingDetails < ActiveRecord::Migration[8.1]
  def change
    # A line across the top of the site: free shipping over $50, a code for a first order.
    add_column :stores, :announcement, :string
    # How long from order to door, in business days, printing included: "arrives Oct 21–24".
    add_column :stores, :delivery_days_min, :integer
    add_column :stores, :delivery_days_max, :integer
    # Measurements buyers check before they pick a size, shown next to the size option.
    add_column :products, :size_guide, :text
    # Which photo shows which option value ({"White" => attachment id}): picking White shows it.
    add_column :products, :option_images, :json, null: false, default: {}
  end
end
