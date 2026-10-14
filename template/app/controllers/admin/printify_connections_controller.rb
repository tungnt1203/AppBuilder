# Connecting the owner's Printify account (Settings › Printify): they paste a personal access
# token, pick the shop when the account has several, and choose whether paid orders go straight
# to production and how they ship. Once a shop is picked, Printify's webhooks are registered when
# the shop has a public https address; update with register_webhooks registers them again, e.g.
# after the shop moved to a new address.
class Admin::PrintifyConnectionsController < Admin::BaseController
  before_action :require_administrator
  before_action :set_store

  def show
    @shops = @store.printify.shops if @store.printify_token.present? && !@store.printify_connected?
  rescue PrintifyGateway::Error => error
    flash.now[:alert] = error.message
  end

  def create
    @store.connect_printify!(params.expect(:token))
    register_webhooks
    redirect_to admin_printify_connection_path, notice: t(".notice")
  rescue PrintifyGateway::Error => error
    redirect_to admin_printify_connection_path, alert: error.message
  end

  def update
    if params[:register_webhooks]
      @store.register_printify_webhooks!(printify_webhook_url)
      return redirect_to(admin_printify_connection_path, notice: t(".notice"))
    end

    attributes = params.expect(store: [ :printify_shop_id, :printify_send_to_production, :printify_shipping_method ])
    if (shop_id = attributes[:printify_shop_id])
      shop = @store.printify.shops.find { |candidate| candidate["id"].to_s == shop_id } or raise PrintifyGateway::Error, t(".unknown_shop")
      attributes[:printify_shop_title] = shop["title"]
    end
    @store.update!(attributes)
    register_webhooks if attributes[:printify_shop_id]
    redirect_to admin_printify_connection_path, notice: t(".notice")
  rescue PrintifyGateway::Error => error
    redirect_to admin_printify_connection_path, alert: error.message
  end

  def destroy
    @store.disconnect_printify!
    redirect_to admin_printify_connection_path, notice: t(".notice"), status: :see_other
  end

  private
    # Without webhooks, the hourly check still ships orders: a failure here doesn't stop the owner.
    def register_webhooks
      @store.register_printify_webhooks!(printify_webhook_url)
    rescue PrintifyGateway::Error => error
      Rails.logger.warn "Couldn't register Printify's webhooks: #{error.message}"
    end

    def set_store
      @store = Store.current
    end
end
