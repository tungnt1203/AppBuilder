class AddRecoverySentAtToOrders < ActiveRecord::Migration[8.1]
  def change
    # When the buyer who left Stripe without paying was emailed a link to finish the order.
    add_column :orders, :recovery_sent_at, :datetime
  end
end
