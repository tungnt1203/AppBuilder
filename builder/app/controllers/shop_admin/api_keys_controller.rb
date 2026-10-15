# The keys the shop's storefronts call the Storefront API with (Settings › Storefront keys), for
# its owners and admins: make one for the published storefront or a preview, see when each was
# last used, revoke one that leaked. A key is shown once, when it's made.
class ShopAdmin::ApiKeysController < ShopAdmin::BaseController
  before_action :require_administrator

  def index
    @api_keys = ShopApiKey.active.order(:created_at)
    @new_key = flash[:api_key]
  end

  def create
    api_key = ShopApiKey.create!(kind: params.expect(api_key: [ :kind ])[:kind].presence_in(ShopApiKey::KINDS) || "storefront")
    redirect_to shop_admin_api_keys_path, notice: t(".notice"), flash: { api_key: api_key.token }
  end

  def destroy
    ShopApiKey.active.find(params[:id]).revoke!
    redirect_to shop_admin_api_keys_path, notice: t(".notice"), status: :see_other
  end
end
