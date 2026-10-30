# What the shop spent on ads a day, per source (facebook, tiktok, google or a utm_source), as the
# owner enters it, for the dashboard's return on ad spend and profit after ads.
class CreateAdSpends < ActiveRecord::Migration[8.1]
  def change
    create_table :ad_spends do |t|
      t.references :shop, null: false, foreign_key: true
      t.date :date, null: false
      t.string :source, null: false
      t.integer :amount_cents, null: false
      t.timestamps
    end
    add_index :ad_spends, %i[ shop_id date source ], unique: true
  end
end
