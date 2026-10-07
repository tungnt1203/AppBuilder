class Admin::SessionsController < Admin::BaseController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_admin_session_path, alert: t("admin.sessions.rate_limited") }

  layout "admin_authentication"

  def new
    redirect_to new_admin_first_run_path unless User.exists?
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_admin_session_path, alert: t(".alert")
    end
  end

  def destroy
    terminate_session
    redirect_to new_admin_session_path, status: :see_other
  end
end
