class AddRefundsToOrders < ActiveRecord::Migration[8.1]
  def change
    # How much of the order went back to the buyer (all of it when refunded or cancelled after
    # paying by card, part of it when refunded partly in Stripe), and when its items went back
    # in stock after a refund.
    add_column :orders, :refunded_cents, :integer, null: false, default: 0
    add_column :orders, :restocked_at, :datetime
  end
end
