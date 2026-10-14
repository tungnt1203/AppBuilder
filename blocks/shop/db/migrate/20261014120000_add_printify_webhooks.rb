class AddPrintifyWebhooks < ActiveRecord::Migration[8.1]
  def change
    # Printify tells the shop when an order ships or arrives, instead of the hourly check.
    add_column :stores, :printify_webhook_url, :string
    add_column :stores, :printify_webhook_secret, :text
    add_column :stores, :printify_webhook_ids, :json, null: false, default: []
  end
end
