class CreateShopCatalog < ActiveRecord::Migration[8.1]
  # The shop core's catalog and settings, moved into the platform from blocks/shop: every table
  # has a shop_id, and every unique index includes it, so two shops can have the same slug, code
  # or Printify product.
  def change
    create_table :stores do |t|
      t.references :shop, null: false, foreign_key: true, index: { unique: true }
      t.string :contact_email
      t.string :contact_phone
      t.text :business_address
      t.integer :shipping_first_item_cents, null: false, default: 0
      t.integer :shipping_additional_item_cents, null: false, default: 0
      t.integer :free_shipping_threshold_cents
      t.jsonb :ship_to_countries, null: false, default: []
      t.boolean :manual_payments, null: false, default: true
      t.text :payment_instructions
      t.text :refund_policy
      t.text :shipping_policy
      t.text :privacy_policy
      t.text :terms_of_service
      t.integer :low_stock_threshold, null: false, default: 5
      t.string :announcement
      t.integer :delivery_days_min
      t.integer :delivery_days_max
      t.text :stripe_secret_key
      t.string :stripe_account_name
      t.string :stripe_webhook_id
      t.string :stripe_webhook_url
      t.text :stripe_webhook_secret
      t.boolean :stripe_tax, null: false, default: false
      t.text :printify_token
      t.string :printify_shop_id
      t.string :printify_shop_title
      t.boolean :printify_send_to_production, null: false, default: true
      t.integer :printify_shipping_method, null: false, default: 1
      t.string :printify_webhook_url
      t.text :printify_webhook_secret
      t.jsonb :printify_webhook_ids, null: false, default: []
      t.string :meta_pixel_id
      t.text :meta_access_token
      t.string :meta_test_event_code
      t.string :meta_error
      t.string :tiktok_pixel_id
      t.string :google_tag_id
      t.timestamps
    end

    create_table :products do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.string :option1_name
      t.string :option2_name
      t.string :option3_name
      t.jsonb :option1_values, null: false, default: []
      t.jsonb :option2_values, null: false, default: []
      t.jsonb :option3_values, null: false, default: []
      t.jsonb :option_images, null: false, default: {}
      t.jsonb :option_colors, null: false, default: {}
      t.text :size_guide
      t.string :printify_product_id
      t.boolean :demo, null: false, default: false
      t.datetime :published_at
      t.timestamps
      t.index [ :shop_id, :slug ], unique: true
      t.index [ :shop_id, :printify_product_id ], unique: true, where: "printify_product_id IS NOT NULL"
      t.index [ :shop_id, :status, :published_at ]
    end

    create_table :variants do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :option1
      t.string :option2
      t.string :option3
      t.string :sku
      t.integer :price_cents, null: false, default: 0
      t.integer :compare_at_price_cents
      t.integer :cost_cents
      t.boolean :available, null: false, default: true
      t.boolean :track_inventory, null: false, default: false
      t.integer :inventory_quantity, null: false, default: 0
      t.integer :printify_variant_id
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [ :product_id, :option1, :option2, :option3 ], unique: true, name: "index_variants_on_product_and_options"
      t.index [ :product_id, :position ]
    end

    create_table :collections do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.boolean :demo, null: false, default: false
      t.timestamps
      t.index [ :shop_id, :slug ], unique: true
    end

    create_table :collection_products do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :collection, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [ :collection_id, :product_id ], unique: true
    end

    create_table :discounts do |t|
      t.references :shop, null: false, foreign_key: true
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
      t.index "shop_id, lower(code)", unique: true, name: "index_discounts_on_shop_id_and_code"
    end

    create_table :promotions do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :percent_off, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "scheduled"
      t.timestamps
      t.index [ :status, :starts_at ]
    end

    create_table :promotion_items do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :promotion, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: { on_delete: :cascade }
      t.integer :original_price_cents
      t.integer :original_compare_at_price_cents
      t.index [ :promotion_id, :variant_id ], unique: true
    end
  end
end
