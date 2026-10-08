class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :collections, :slug, unique: true

    create_table :collection_products do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :collection_products, [ :collection_id, :product_id ], unique: true
  end
end
