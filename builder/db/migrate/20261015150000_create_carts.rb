class CreateCarts < ActiveRecord::Migration[8.1]
  def change
    # A buyer's cart in a shop; the storefront holds its token.
    create_table :carts do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :token, null: false, index: { unique: true }
      t.string :discount_code
      t.timestamps
      t.index [ :shop_id, :updated_at ]
    end

    create_table :cart_items do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :cart, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.timestamps
      t.index [ :cart_id, :variant_id ], unique: true
    end
  end
end
