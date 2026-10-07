class AddPaymentsAndPoliciesToStores < ActiveRecord::Migration[8.1]
  def change
    change_table :stores do |t|
      t.text :stripe_secret_key
      t.string :stripe_account_name
      t.string :stripe_webhook_id
      t.string :stripe_webhook_url
      t.text :stripe_webhook_secret
      t.boolean :manual_payments, default: true, null: false

      t.string :contact_phone
      t.text :business_address
      t.text :refund_policy
      t.text :shipping_policy
      t.text :privacy_policy
      t.text :terms_of_service
    end
  end
end
