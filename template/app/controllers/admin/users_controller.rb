class Admin::UsersController < Admin::BaseController
  before_action :require_administrator
  before_action :set_user, only: %i[ show edit update destroy ]

  def index
    @users = User.ordered
  end

  def show
    @invitation_url = admin_invitation_url(@user.generate_token_for(:invitation))
  end

  def new
    @user = User.new
  end

  def create
    @user = User.invite(user_params)

    if @user.persisted?
      Admin::InvitationsMailer.invite(@user).deliver_later
      redirect_to admin_user_path(@user), notice: t(".notice", name: @user.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_users_path, notice: t(".notice", name: @user.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == Current.user
      redirect_to admin_users_path, alert: t(".cannot_remove_self")
    elsif @user.destroy
      redirect_to admin_users_path, notice: t(".notice", name: @user.name), status: :see_other
    else
      redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.expect(user: [ :name, :email_address, :role ]).tap do |permitted|
        permitted.delete(:role) if permitted[:role] == "owner"
      end
    end
end
