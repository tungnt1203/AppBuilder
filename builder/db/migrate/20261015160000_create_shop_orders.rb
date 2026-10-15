class CreateShopOrders < ActiveRecord::Migration[8.1]
  # The shop core's orders, buyers' accounts and reviews, moved into the platform from
  # blocks/shop: every table has a shop_id; order numbers count up within each shop.
  def change
    create_table :customers do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.timestamps
      t.index [ :shop_id, :email_address ], unique: true
    end

    create_table :orders do |t|
      t.references :shop, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :token, null: false, index: { unique: true }
      t.string :status, null: false, default: "pending"
      t.references :customer, foreign_key: { on_delete: :nullify }
      t.references :cart, foreign_key: { on_delete: :nullify }
      t.references :discount, foreign_key: { on_delete: :nullify }
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
      t.integer :discount_cents, null: false, default: 0
      t.string :discount_code
      t.integer :shipping_cents, null: false, default: 0
      t.integer :tax_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.integer :refunded_cents, null: false, default: 0
      t.string :payment_method, null: false, default: "manual"
      t.string :payment_reference
      t.string :stripe_checkout_session_id, index: { unique: true }
      t.string :carrier
      t.string :tracking_number
      t.string :tracking_url
      t.string :printify_order_id
      t.text :fulfillment_error
      t.integer :fulfillment_cost_cents
      t.jsonb :attribution
      t.datetime :paid_at
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.datetime :cancelled_at
      t.datetime :refunded_at
      t.datetime :restocked_at
      t.datetime :recovery_sent_at
      t.datetime :purchase_reported_at
      t.datetime :review_requested_at
      t.timestamps
      t.index [ :shop_id, :number ], unique: true
      t.index [ :shop_id, :status, :created_at ]
      t.index [ :shop_id, :email ]
      t.index [ :shop_id, :printify_order_id ]
    end

    create_table :line_items do |t|
      t.references :shop, null: false, foreign_key: true
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
      t.references :shop, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :action, null: false
      t.text :message
      t.timestamps
    end

    create_table :product_reviews do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :body
      t.string :author_name, null: false
      t.string :status, null: false, default: "published"
      t.timestamps
      t.index [ :order_id, :product_id ], unique: true
      t.index [ :product_id, :status, :created_at ]
    end
  end
end
