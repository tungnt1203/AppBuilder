class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.integer :number, null: false
      t.string :token, null: false
      t.string :status, null: false, default: "pending"
      t.references :customer, foreign_key: true

      t.string :email, null: false
      t.string :phone
      t.string :shipping_name, null: false
      t.string :shipping_address1, null: false
      t.string :shipping_address2
      t.string :shipping_city, null: false
      t.string :shipping_region
      t.string :shipping_postal_code
      t.string :shipping_country, null: false
      t.text :note
      t.text :staff_note

      t.string :currency, null: false
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :shipping_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0

      t.string :payment_method, null: false, default: "manual"
      t.string :payment_reference
      t.string :carrier
      t.string :tracking_number
      t.string :tracking_url

      t.datetime :paid_at
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.datetime :cancelled_at
      t.datetime :refunded_at

      t.timestamps
    end
    add_index :orders, :number, unique: true
    add_index :orders, :token, unique: true
    add_index :orders, [ :status, :created_at ]
    add_index :orders, :email

    create_table :line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :variant, foreign_key: { on_delete: :nullify }
      t.string :product_title, null: false
      t.string :variant_title
      t.string :sku
      t.integer :unit_price_cents, null: false
      t.integer :quantity, null: false

      t.timestamps
    end

    create_table :order_events do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :action, null: false
      t.text :message

      t.timestamps
    end
  end
end
