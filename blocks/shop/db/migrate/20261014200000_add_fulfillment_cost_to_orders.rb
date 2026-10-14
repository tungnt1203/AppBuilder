class AddFulfillmentCostToOrders < ActiveRecord::Migration[8.1]
  def change
    # What Printify bills the shop for the order (printing, shipping and its tax), once it has it.
    add_column :orders, :fulfillment_cost_cents, :integer
  end
end
