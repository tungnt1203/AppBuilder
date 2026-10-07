class AddTouredAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :toured_at, :datetime
  end
end
