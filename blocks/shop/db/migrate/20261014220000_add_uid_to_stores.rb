class AddUidToStores < ActiveRecord::Migration[8.1]
  def change
    # A short code of this shop's own (Store#uid), in what it sends to a Stripe or Printify
    # account other shops of the same owner may share, so each shop knows its own orders there.
    add_column :stores, :uid, :string
  end
end
