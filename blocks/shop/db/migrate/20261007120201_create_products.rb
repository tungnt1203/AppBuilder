class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.string :option1_name
      t.string :option2_name
      t.string :option3_name
      t.json :option1_values, null: false, default: []
      t.json :option2_values, null: false, default: []
      t.json :option3_values, null: false, default: []
      t.datetime :published_at

      t.timestamps
    end
    add_index :products, :slug, unique: true
    add_index :products, [ :status, :published_at ]

    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :option1
      t.string :option2
      t.string :option3
      t.string :sku
      t.integer :price_cents, null: false, default: 0
      t.integer :compare_at_price_cents
      t.boolean :available, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :variants, [ :product_id, :option1, :option2, :option3 ], unique: true, name: "index_variants_on_product_and_options"
    add_index :variants, [ :product_id, :position ]
  end
end
