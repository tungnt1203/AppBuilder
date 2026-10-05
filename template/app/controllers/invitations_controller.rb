# Lets an invited user set their password from the link an admin shared.
class InvitationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token

  layout "authentication"

  def show
  end

  def update
    if @user.update(params.expect(user: [ :password ]))
      start_new_session_for @user
      redirect_to root_path, notice: t(".notice", name: @user.name)
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_token_for(:invitation, params[:token])
      redirect_to new_session_path, alert: t("invitations.invalid") unless @user
    end
end
