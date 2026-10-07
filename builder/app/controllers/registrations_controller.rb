# Anyone can create an account. The very first one also runs the studio (see User).
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  layout "authentication"

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.expect(user: [ :name, :email_address, :password ]))

    if @user.save
      start_new_session_for @user
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end
end
