class AddInventoryToVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :variants, :track_inventory, :boolean, null: false, default: false
    add_column :variants, :inventory_quantity, :integer, null: false, default: 0
    add_column :variants, :cost_cents, :integer
    add_column :stores, :low_stock_threshold, :integer, null: false, default: 5
  end
end
