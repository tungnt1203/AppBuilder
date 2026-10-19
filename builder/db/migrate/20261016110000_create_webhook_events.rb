class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    # What Stripe and Printify told each shop, once per event: to look into what happened to an
    # order, and so a delivery Stripe or Printify sends again isn't handled twice.
    create_table :webhook_events do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :event_id, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: "received"
      t.references :order, foreign_key: { on_delete: :nullify }
      t.text :error
      t.jsonb :payload, null: false, default: {}
      t.timestamps
      t.index [ :shop_id, :provider, :event_id ], unique: true
      t.index [ :shop_id, :created_at ]
    end
  end
end
