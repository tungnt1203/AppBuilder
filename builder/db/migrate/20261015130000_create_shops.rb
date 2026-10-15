class CreateShops < ActiveRecord::Migration[8.1]
  def change
    # A shop of the platform: its storefront's address and its own data (every shop table has a
    # shop_id). Owners and staff reach it through memberships; storefronts through API keys.
    create_table :shops do |t|
      t.string :name, null: false
      t.string :subdomain, null: false, index: { unique: true }
      t.string :uid, null: false, index: { unique: true }
      t.string :currency, null: false, default: "USD"
      t.string :time_zone, null: false, default: "UTC"
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    create_table :shop_memberships do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "staff"
      t.timestamps
      t.index [ :shop_id, :user_id ], unique: true
    end

    # A storefront's key: only its digest is kept; the key itself is shown once.
    create_table :shop_api_keys do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :kind, null: false, default: "storefront"
      t.string :token_digest, null: false, index: { unique: true }
      t.string :token_hint, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_reference :projects, :shop, foreign_key: true
  end
end
