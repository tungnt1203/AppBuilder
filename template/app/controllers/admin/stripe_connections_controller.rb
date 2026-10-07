# Connecting the shop's Stripe account (Settings): the owner pastes a secret key from the Stripe
# dashboard. Update registers the webhook again, e.g. after the shop moved to a new address.
class Admin::StripeConnectionsController < Admin::BaseController
  before_action :require_administrator

  def create
    Store.current.connect_stripe!(params[:secret_key], webhook_url: stripe_webhook_url)
    redirect_to edit_admin_settings_path(anchor: "payments"), notice: t(".notice")
  rescue StripeGateway::Error => error
    redirect_to edit_admin_settings_path(anchor: "payments"), alert: t(".failed", error: error.message)
  end

  def update
    Store.current.register_stripe_webhook!(stripe_webhook_url)
    redirect_to edit_admin_settings_path(anchor: "payments"), notice: t(".notice")
  rescue StripeGateway::Error => error
    redirect_to edit_admin_settings_path(anchor: "payments"), alert: t(".failed", error: error.message)
  end

  def destroy
    Store.current.disconnect_stripe!
    redirect_to edit_admin_settings_path(anchor: "payments"), notice: t(".notice")
  end
end
