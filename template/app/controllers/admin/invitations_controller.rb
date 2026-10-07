# Lets an invited user set their password from the link an admin shared.
class Admin::InvitationsController < Admin::BaseController
  allow_unauthenticated_access
  before_action :set_user_by_token

  layout "admin_authentication"

  def show
  end

  def update
    if @user.update(params.expect(user: [ :password ]))
      start_new_session_for @user
      redirect_to admin_root_path, notice: t(".notice", name: @user.name)
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_token_for(:invitation, params[:token])
      redirect_to new_admin_session_path, alert: t("admin.invitations.invalid") unless @user
    end
end
