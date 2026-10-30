# A storefront visitor's day: the furthest they got (a page, a product, the cart, checkout, an
# order) and where they came from, for the dashboard's funnel. The visitor is the storefront's
# random cookie id, digested: nothing that names anyone.
class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :shop, null: false, foreign_key: true, index: false
      t.date :date, null: false
      t.string :visitor, null: false
      t.string :source, null: false, default: "direct"
      t.integer :step, null: false, default: 1
      t.timestamps
    end
    add_index :visits, %i[ shop_id date visitor ], unique: true
  end
end
