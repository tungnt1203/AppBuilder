# Every screen of /admin, where the owner and staff run the app, inherits from this.
# Sign in is required unless a controller calls allow_unauthenticated_access.
class Admin::BaseController < ActionController::Base
  include Admin::Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  layout "admin"

  private
    def require_administrator
      redirect_to admin_root_path, alert: t("admin.base.only_admins") unless Current.user.administrator?
    end
end
