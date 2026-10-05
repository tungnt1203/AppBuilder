# Creates the owner account the first time the app is opened.
class FirstRunsController < ApplicationController
  allow_unauthenticated_access
  before_action :prevent_repeats

  layout "authentication"

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params.merge(role: :owner))

    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome! Your account is ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def prevent_repeats
      redirect_to root_path if User.exists?
    end

    def user_params
      params.expect(user: [ :name, :email_address, :password ])
    end
end
