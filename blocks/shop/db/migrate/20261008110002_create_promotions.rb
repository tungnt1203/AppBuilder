class CreatePromotions < ActiveRecord::Migration[8.1]
  def change
    # A sale: the variants' prices lowered by percent_off from starts_at to ends_at.
    create_table :promotions do |t|
      t.string :name, null: false
      t.integer :percent_off, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "scheduled"

      t.timestamps
    end
    add_index :promotions, [ :status, :starts_at ]

    # Each variant's price before the sale, so it goes back to exactly that.
    create_table :promotion_items do |t|
      t.references :promotion, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: { on_delete: :cascade }
      t.integer :original_price_cents
      t.integer :original_compare_at_price_cents
    end
    add_index :promotion_items, [ :promotion_id, :variant_id ], unique: true
  end
end
