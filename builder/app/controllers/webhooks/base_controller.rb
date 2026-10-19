# Stripe and Printify call the platform here for every shop: /webhooks/<provider>/<shop's uid>,
# registered when the shop connects its account (ShopAdmin::BaseController#stripe_webhook_url).
# The address picks the shop, whose secret checks the signature and whose data the event may
# change: a shop sharing a Stripe or Printify account with others gets their events too, and
# ignores them (none of its orders match), so one shop's account can't touch another's orders.
class Webhooks::BaseController < ActionController::API
  set_current_tenant_through_filter
  before_action :set_shop

  private
    def set_shop
      shop = ActsAsTenant.without_tenant { Shop.find_by(uid: params[:shop_uid]) } or return head(:not_found)
      set_current_tenant(shop)
    end

    def store = @store ||= Store.current
end
