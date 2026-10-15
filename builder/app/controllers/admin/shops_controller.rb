# The shops an account runs, and opening a new one: its name and the subdomain its storefront is
# published at. Whoever opens it is its owner.
class Admin::ShopsController < Admin::BaseController
  def index
    @memberships = Current.user.shop_memberships.includes(:shop).order("shops.name")
  end

  def new
    @shop = Shop.new(currency: "USD")
  end

  def create
    @shop = Shop.new(shop_params)

    if @shop.valid?
      shop = Shop.open!(owner: Current.user, **shop_params.to_h.symbolize_keys)
      BusinessSyncJob.perform_later(shop, Current.user) if Current.user.business_setting&.configured?
      redirect_to shop_admin_root_path(shop), notice: "#{shop.name} is open. Add its products, then connect Stripe and Printify in its settings."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def shop_params
      params.expect(shop: %i[ name subdomain currency ])
    end
end
