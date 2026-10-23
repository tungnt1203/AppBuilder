# The shop's settings: currency, shipping, where it ships, how buyers pay. Admins only.
# Stripe is connected in ShopAdmin::StripeConnectionsController, policies in ShopAdmin::PoliciesController.
class ShopAdmin::SettingsController < ShopAdmin::BaseController
  before_action :require_administrator
  before_action :set_store

  def edit
  end

  # The currency is the shop's own (Shop#currency); the rest is its Store's.
  def update
    attributes = store_params
    current_shop.currency = attributes.delete(:currency) if attributes.key?(:currency)
    @store.assign_attributes(attributes)

    if current_shop.valid? & @store.valid? # both, for all the mistakes at once
      Store.transaction { current_shop.save! && @store.save! }
      redirect_to edit_shop_admin_settings_path, notice: t(".notice")
    else
      current_shop.errors.each { |error| @store.errors.add(error.attribute, error.message) }
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_store
      @store = Store.current
    end

    def store_params
      params.expect(store: [ :currency, :shipping_first_item, :shipping_additional_item,
        :free_shipping_threshold, :ship_to_countries_text, :announcement, :delivery_days_min, :delivery_days_max,
        :meta_pixel_id, :meta_access_token, :meta_test_event_code, :tiktok_pixel_id, :google_tag_id,
        :payment_instructions, :manual_payments, :stripe_tax, :low_stock_threshold ]).then { |store| keep_meta_access_token(store) }
    end

    # The token isn't shown again: an empty field keeps the saved one, unless the owner removes it.
    def keep_meta_access_token(store)
      if params[:remove_meta_access_token].present?
        store.merge(meta_access_token: nil)
      elsif store[:meta_access_token].blank?
        store.except(:meta_access_token)
      else
        store
      end
    end
end
