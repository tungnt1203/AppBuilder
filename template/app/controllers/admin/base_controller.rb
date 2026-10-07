# Every screen of /admin, where the owner and staff run the app, inherits from this.
# Sign in is required unless a controller calls allow_unauthenticated_access.
class Admin::BaseController < ActionController::Base
  include Admin::Authentication, Pagination

  allow_browser versions: :modern
  stale_when_importmap_changes

  layout "admin"

  around_action :use_admin_locale

  private
    # /admin speaks the owner's language (config.x.admin_locale), whatever the site's is.
    def use_admin_locale(&)
      I18n.with_locale(Rails.configuration.x.admin_locale || I18n.default_locale, &)
    end

    def require_administrator
      redirect_to admin_root_path, alert: t("admin.base.only_admins") unless Current.user.administrator?
    end
end
