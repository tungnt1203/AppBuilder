# Customers sign in and out of the customers' site.
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") }

  def new
    redirect_to account_path if customer_signed_in?
  end

  def create
    if customer = Customer.authenticate_by(params.permit(:email_address, :password))
      start_customer_session_for customer
      redirect_to after_customer_sign_in_url
    else
      redirect_to new_session_path(email_address: params[:email_address]), alert: t(".alert")
    end
  end

  def destroy
    end_customer_session
    redirect_to root_path, status: :see_other
  end
end
