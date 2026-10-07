class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.string :currency, null: false, default: "USD"
      t.string :contact_email
      t.integer :shipping_first_item_cents, null: false, default: 0
      t.integer :shipping_additional_item_cents, null: false, default: 0
      t.integer :free_shipping_threshold_cents
      t.json :ship_to_countries, null: false, default: []
      t.text :payment_instructions

      t.timestamps
    end
  end
end
