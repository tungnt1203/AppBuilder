class CreateDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :discounts do |t|
      t.string :code, null: false
      t.string :kind, null: false, default: "percentage"
      t.integer :percent_off
      t.integer :amount_off_cents
      t.integer :minimum_subtotal_cents
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :usage_limit
      t.integer :times_used, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :discounts, :code, unique: true

    add_column :carts, :discount_code, :string
    add_reference :orders, :discount, foreign_key: { on_delete: :nullify }
    add_column :orders, :discount_code, :string
    add_column :orders, :discount_cents, :integer, null: false, default: 0
    add_column :orders, :tax_cents, :integer, null: false, default: 0
    add_column :stores, :stripe_tax, :boolean, null: false, default: false
  end
end
