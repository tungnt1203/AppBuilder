class AddMetaConversions < ActiveRecord::Migration[8.1]
  def change
    # Meta's Conversions API: purchases go to Meta from the server too, so ads still learn about
    # the ones the pixel misses (blockers, iOS, a buyer who never comes back from Stripe).
    add_column :stores, :meta_access_token, :text
    add_column :stores, :meta_test_event_code, :string
    add_column :stores, :meta_error, :string

    # The buyer's browser when they checked out (Meta's cookies, IP, user agent, page), sent with
    # the purchase so Meta can match it to the ad they came from.
    add_column :orders, :attribution, :json
    add_column :orders, :purchase_reported_at, :datetime
  end
end
