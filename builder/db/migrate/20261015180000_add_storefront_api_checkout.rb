# Checkout through the Storefront API: orders a preview places are tests (never printed, never
# counted), card payments are PaymentIntents the storefront confirms with Stripe's Payment
# Element (which needs the account's publishable key) instead of Checkout Sessions, and a
# checkout or payment sent twice with the same Idempotency-Key gets the first answer again.
class AddStorefrontApiCheckout < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :test, :boolean, default: false, null: false
    add_column :orders, :stripe_payment_intent_id, :string
    add_column :orders, :stripe_tax_calculation_id, :string
    remove_column :orders, :stripe_checkout_session_id, :string
    add_index :orders, :stripe_payment_intent_id, unique: true
    add_column :stores, :stripe_publishable_key, :string

    create_table :api_idempotency_keys do |t|
      t.references :shop, null: false, foreign_key: true, index: false
      t.string :key, null: false
      t.string :fingerprint, null: false
      t.integer :response_status
      t.jsonb :response_body
      t.timestamps
      t.index %i[ shop_id key ], unique: true
      t.index :created_at
    end
  end
end
