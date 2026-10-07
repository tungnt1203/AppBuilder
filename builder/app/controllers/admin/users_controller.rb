# Accounts, for administrators: who has one, how many apps they made, and who else
# may manage accounts and open every app.
class Admin::UsersController < ApplicationController
  before_action :require_administrator
  before_action :set_user, only: %i[ update destroy ]

  def index
    @users = User.ordered.left_joins(:projects).group(:id).select("users.*, COUNT(projects.id) AS projects_count")
  end

  def update
    @user.update(role: params.expect(user: [ :role ])[:role]) if @user.role_changeable_by?(Current.user)
    redirect_to admin_users_path, status: :see_other
  end

  # Only accounts without apps: an app's previews, code and published copy need someone
  # to look after them.
  def destroy
    if @user.removable_by?(Current.user)
      @user.destroy
      redirect_to admin_users_path, status: :see_other, notice: "#{@user.name}'s account was removed."
    else
      redirect_to admin_users_path, status: :see_other
    end
  end

  private
    def require_administrator
      head :not_found unless Current.user.administrator?
    end

    def set_user
      @user = User.find(params[:id])
    end
end
