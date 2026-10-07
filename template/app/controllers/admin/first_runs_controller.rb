# Creates the owner account the first time the app is opened.
class Admin::FirstRunsController < Admin::BaseController
  allow_unauthenticated_access
  before_action :prevent_repeats

  layout "admin_authentication"

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params.merge(role: :owner))

    if @user.save
      start_new_session_for @user
      redirect_to admin_root_path, notice: t(".notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def prevent_repeats
      redirect_to admin_root_path if User.exists?
    end

    def user_params
      params.expect(user: [ :name, :email_address, :password ])
    end
end
