# The shop's settings: currency, shipping, where it ships, how buyers pay. Admins only.
# Stripe is connected in Admin::StripeConnectionsController, policies in Admin::PoliciesController.
class Admin::SettingsController < Admin::BaseController
  before_action :require_administrator
  before_action :set_store

  def edit
  end

  def update
    if @store.update(store_params)
      redirect_to edit_admin_settings_path, notice: t(".notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_store
      @store = Store.current
    end

    def store_params
      params.expect(store: [ :currency, :contact_email, :shipping_first_item, :shipping_additional_item,
        :free_shipping_threshold, :ship_to_countries_text, :payment_instructions, :manual_payments, :stripe_tax, :low_stock_threshold ])
    end
end
