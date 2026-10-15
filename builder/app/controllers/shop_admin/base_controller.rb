# Every screen of a shop's admin (/admin/shops/:shop_id/…), inside the platform's admin layout
# with the shop picked in its sidebar. The signed-in account must be one of the shop's members:
# the shop is then the current tenant, so queries only see its data. Staff do the daily work
# (orders, products, reviews); settings and people are for its owners and admins.
class ShopAdmin::BaseController < ApplicationController
  include Pagination

  layout "admin"
  default_form_builder UiFormBuilder

  set_current_tenant_through_filter
  before_action :set_shop

  helper_method :current_shop, :current_membership, :shop_administrator?, :stripe_webhook_url, :printify_webhook_url

  private
    # Someone else's shop looks like one that doesn't exist.
    def set_shop
      @current_membership = Current.user.shop_memberships.joins(:shop).includes(:shop).find_by!(shops: { subdomain: params[:shop_id] })
      set_current_tenant(@current_membership.shop)
    end

    def current_shop = @current_membership&.shop
    def current_membership = @current_membership
    def shop_administrator? = @current_membership.administrator?

    # The shop's paths take it from here: shop_admin_order_path(order). Paths outside the shop
    # say shop_id: nil, or they'd carry it along as ?shop_id=.
    def default_url_options
      current_shop ? { shop_id: current_shop } : {}
    end

    def require_administrator
      redirect_to shop_admin_root_path, alert: t("shop_admin.base.only_admins") unless shop_administrator?
    end

    # Stripe and Printify call the platform at one address for every shop, from Platform v1 (7/10);
    # until then payments are confirmed when buyers come back from Stripe, and the hourly check
    # ships Printify orders.
    def stripe_webhook_url = nil
    def printify_webhook_url = nil
end
