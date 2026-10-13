class AddPrintify < ActiveRecord::Migration[8.1]
  def change
    # The owner's Printify account: paid orders go there to be printed and shipped.
    add_column :stores, :printify_token, :text
    add_column :stores, :printify_shop_id, :string
    add_column :stores, :printify_shop_title, :string
    add_column :stores, :printify_send_to_production, :boolean, null: false, default: true
    add_column :stores, :printify_shipping_method, :integer, null: false, default: 1

    add_column :products, :printify_product_id, :string
    add_index :products, :printify_product_id, unique: true
    add_column :variants, :printify_variant_id, :integer

    add_column :orders, :printify_order_id, :string
    add_column :orders, :fulfillment_error, :text
  end
end
