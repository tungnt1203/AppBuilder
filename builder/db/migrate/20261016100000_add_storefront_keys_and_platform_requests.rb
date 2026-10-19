class AddStorefrontKeysAndPlatformRequests < ActiveRecord::Migration[8.1]
  def change
    # The shop keys a project's storefront runs with, encrypted: the preview's and the published one's.
    add_column :projects, :preview_shop_key, :text
    add_column :projects, :live_shop_key, :text

    # What a storefront's agent asked the Platform for when the shop's data didn't have it.
    create_table :platform_requests do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :project, foreign_key: true
      t.text :body, null: false
      t.string :status, null: false, default: "open"
      t.integer :times_asked, null: false, default: 1
      t.timestamps
      t.index [ :shop_id, :status ]
    end
  end
end
