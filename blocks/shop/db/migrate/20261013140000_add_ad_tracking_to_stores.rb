class AddAdTrackingToStores < ActiveRecord::Migration[8.1]
  def change
    # The owner's ad accounts, so ads learn which visits turn into orders.
    add_column :stores, :meta_pixel_id, :string
    add_column :stores, :tiktok_pixel_id, :string
    add_column :stores, :google_tag_id, :string
  end
end
