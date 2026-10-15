# The owner's settings carry their Stripe publishable key too, for every shop's Payment Element.
class AddStripePublishableKeyToBusinessSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :business_settings, :stripe_publishable_key, :string
  end
end
