class CreateBusinessSettings < ActiveRecord::Migration[8.1]
  def change
    # What an owner sets once for all their shops (Stripe, Printify, ad pixels); the builder
    # applies it to each of their apps (BusinessSync).
    create_table :business_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :stripe_secret_key
      t.text :printify_token
      t.string :printify_shop_id
      t.string :printify_shop_title
      t.string :meta_pixel_id
      t.text :meta_access_token
      t.string :tiktok_pixel_id
      t.string :google_tag_id
      t.timestamps
    end

    # How the last time went for each app: when, and what the app said (or why it failed).
    add_column :projects, :business_synced_at, :datetime
    add_column :projects, :business_sync_result, :json
  end
end
