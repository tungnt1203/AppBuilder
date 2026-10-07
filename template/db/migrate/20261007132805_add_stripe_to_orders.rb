class AddStripeToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :stripe_checkout_session_id, :string
    add_column :orders, :cart_id, :integer
    add_index :orders, :stripe_checkout_session_id, unique: true
  end
end
