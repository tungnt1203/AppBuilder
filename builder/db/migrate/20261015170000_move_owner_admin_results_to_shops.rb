# The owner's admin reads and writes each shop's data directly: what applying the owner's
# settings and importing from Printify did is kept on the shop, and the apps' answers about
# their orders aren't needed any more.
class MoveOwnerAdminResultsToShops < ActiveRecord::Migration[8.1]
  def change
    change_table :shops, bulk: true do |t|
      t.datetime :business_synced_at
      t.jsonb :business_sync_result
      t.datetime :printify_imported_at
      t.jsonb :printify_import_result
    end

    change_table :projects, bulk: true do |t|
      t.remove :business_synced_at, type: :datetime
      t.remove :business_sync_result, type: :json
      t.remove :orders_summary, type: :json
      t.remove :orders_summary_at, type: :datetime
      t.remove :orders_summary_source, type: :string
      t.remove :printify_imported_at, type: :datetime
      t.remove :printify_import_result, type: :json
    end
  end
end
