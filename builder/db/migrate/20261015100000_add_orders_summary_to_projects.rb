class AddOrdersSummaryToProjects < ActiveRecord::Migration[8.1]
  def change
    # The shop at a glance (its OrdersSummary), for the owner's orders board across their shops:
    # from its published copy when it has one, else its preview.
    add_column :projects, :orders_summary, :json
    add_column :projects, :orders_summary_at, :datetime
    add_column :projects, :orders_summary_source, :string
  end
end
