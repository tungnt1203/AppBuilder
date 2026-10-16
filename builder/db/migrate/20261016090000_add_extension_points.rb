class AddExtensionPoints < ActiveRecord::Migration[8.1]
  # What a storefront can show and collect beyond the catalog: theme values, custom product
  # fields, text the buyer types (carried onto the order and to Printify), pages, menus and forms.
  # Every table has shop_id, and every unique index includes it.
  def change
    create_table :theme_settings do |t|
      t.references :shop, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :schema, null: false, default: []
      t.string :schema_version
      t.jsonb :values, null: false, default: {}
      t.timestamps
    end

    create_table :custom_field_definitions do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.string :field_type, null: false, default: "text"
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [ :shop_id, :key ], unique: true
    end

    create_table :pages do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :body
      t.jsonb :faqs, null: false, default: []
      t.boolean :published, null: false, default: false
      t.timestamps
      t.index [ :shop_id, :slug ], unique: true
    end

    create_table :menus do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :key, null: false
      t.string :title, null: false
      t.jsonb :items, null: false, default: []
      t.timestamps
      t.index [ :shop_id, :key ], unique: true
    end

    create_table :forms do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :key, null: false
      t.string :title, null: false
      t.jsonb :fields, null: false, default: []
      t.timestamps
      t.index [ :shop_id, :key ], unique: true
    end

    create_table :form_submissions do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :form, null: false, foreign_key: true
      t.jsonb :answers, null: false, default: {}
      t.timestamps
      t.index [ :form_id, :created_at ]
    end

    change_table :products do |t|
      t.jsonb :custom_fields, null: false, default: {}
      t.jsonb :buyer_inputs, null: false, default: []
    end

    add_column :cart_items, :properties, :jsonb, null: false, default: {}
    remove_index :cart_items, name: "index_cart_items_on_cart_id_and_variant_id"
    add_index :cart_items, [ :cart_id, :variant_id, :properties ], unique: true, name: "index_cart_items_on_cart_id_and_variant_id_and_properties"

    add_column :line_items, :properties, :jsonb, null: false, default: {}
  end
end
