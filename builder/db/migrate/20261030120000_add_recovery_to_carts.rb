# The email a buyer typed at checkout before leaving, for the one reminder of their cart
# (Cart::RecoveryJob), and when it went.
class AddRecoveryToCarts < ActiveRecord::Migration[8.1]
  def change
    add_column :carts, :email, :string
    add_column :carts, :recovery_sent_at, :datetime
  end
end
