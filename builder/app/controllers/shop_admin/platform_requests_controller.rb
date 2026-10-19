# What the storefront's agent asked the Platform for (PlatformRequest): the owner reads what their
# storefront is waiting on; the builder's administrators mark each done or declined.
class ShopAdmin::PlatformRequestsController < ShopAdmin::BaseController
  before_action :require_administrator
  before_action :require_platform_administrator, only: :update

  def index
    @requests = PlatformRequest.newest_first.includes(:project)
  end

  def update
    PlatformRequest.find(params[:id]).update!(status: params.expect(:status))
    redirect_to shop_admin_platform_requests_path, notice: t(".notice"), status: :see_other
  end

  private
    def require_platform_administrator
      redirect_to shop_admin_platform_requests_path, alert: t(".only_platform") unless Current.user.administrator?
    end
end
