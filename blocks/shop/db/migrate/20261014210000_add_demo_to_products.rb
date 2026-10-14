class AddDemoToProducts < ActiveRecord::Migration[8.1]
  def change
    # Products and collections the owner added with "Add demo products" (DemoCatalog), to show
    # the shop before theirs are in; removed together with "Remove demo products".
    add_column :products, :demo, :boolean, null: false, default: false
    add_column :collections, :demo, :boolean, null: false, default: false
  end
end
