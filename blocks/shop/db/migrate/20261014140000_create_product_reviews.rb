class CreateProductReviews < ActiveRecord::Migration[8.1]
  def change
    # Reviews by buyers of the product, one per product and order: only someone who bought it can
    # write one, from the link in their order's email.
    create_table :product_reviews do |t|
      t.references :product, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :body
      t.string :author_name, null: false
      t.string :status, null: false, default: "published"
      t.timestamps
    end
    add_index :product_reviews, %i[ order_id product_id ], unique: true
    add_index :product_reviews, %i[ product_id status created_at ]

    add_column :orders, :review_requested_at, :datetime
  end
end
