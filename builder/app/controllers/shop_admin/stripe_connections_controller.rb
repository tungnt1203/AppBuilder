# Connecting the shop's Stripe account (Settings): the owner pastes its secret and publishable
# keys from the Stripe dashboard. Update adds the publishable key to a connected account, or
# registers the webhook again.
class ShopAdmin::StripeConnectionsController < ShopAdmin::BaseController
  before_action :require_administrator

  def create
    Store.current.connect_stripe!(params[:secret_key], publishable_key: params[:publishable_key], webhook_url: stripe_webhook_url)
    redirect_to edit_shop_admin_settings_path(anchor: "payments"), notice: t(".notice")
  rescue StripeGateway::Error => error
    redirect_to edit_shop_admin_settings_path(anchor: "payments"), alert: t(".failed", error: error.message)
  end

  def update
    if params.key?(:publishable_key)
      store = Store.current
      return redirect_to(edit_shop_admin_settings_path(anchor: "payments"), notice: t(".publishable_key_saved")) if store.update(stripe_publishable_key: params[:publishable_key])

      redirect_to edit_shop_admin_settings_path(anchor: "payments"), alert: store.errors.full_messages.to_sentence
    else
      Store.current.register_stripe_webhook!(stripe_webhook_url)
      redirect_to edit_shop_admin_settings_path(anchor: "payments"), notice: t(".notice")
    end
  rescue StripeGateway::Error => error
    redirect_to edit_shop_admin_settings_path(anchor: "payments"), alert: t(".failed", error: error.message)
  end

  def destroy
    Store.current.disconnect_stripe!
    redirect_to edit_shop_admin_settings_path(anchor: "payments"), notice: t(".notice")
  end
end
