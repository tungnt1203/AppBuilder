# The shop's Meta ad account, whose daily spend is brought into Ad spend (AdSpend::MetaImportJob),
# with when it last came and what went wrong.
class AddMetaAdAccountToStores < ActiveRecord::Migration[8.1]
  def change
    add_column :stores, :meta_ad_account_id, :string
    add_column :stores, :meta_ad_spend_error, :text
    add_column :stores, :meta_ad_spend_synced_at, :datetime
  end
end
