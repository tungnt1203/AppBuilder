class CreateBuyerUploads < ActiveRecord::Migration[8.1]
  def change
    # Photos buyers add to personalized products (a family photo on a mug), before they buy: a cart
    # or order line keeps the token, and the photo is printed from here.
    create_table :buyer_uploads do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :token, null: false
      t.integer :width
      t.integer :height
      t.timestamps
      t.index :token, unique: true
      t.index [ :shop_id, :created_at ]
    end
  end
end
