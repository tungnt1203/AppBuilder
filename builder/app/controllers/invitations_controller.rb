# Someone a shop's owner added (ShopAdmin::MembershipsController) chooses their password from the
# invitation link, then lands in the shop's admin.
class InvitationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token

  layout "authentication"

  def show
  end

  def update
    if @user.update(params.expect(user: [ :password ]))
      start_new_session_for @user
      shop = @user.shops.order(:id).first
      redirect_to shop ? shop_admin_root_path(shop) : root_path, notice: "Welcome, #{@user.name}."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_token_for(:invitation, params[:token])
      redirect_to new_session_path, alert: "That invitation has expired or was already used. Ask for a new one, or reset your password." unless @user
    end
end
