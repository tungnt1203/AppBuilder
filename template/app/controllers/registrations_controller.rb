# Customers create their own account on the customers' site.
class RegistrationsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: t("sessions.rate_limited") }

  def new
    redirect_to account_path if customer_signed_in?
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(params.expect(customer: [ :name, :email_address, :password ]))

    if @customer.save
      start_customer_session_for @customer
      redirect_to after_customer_sign_in_url, notice: t(".notice", name: @customer.name)
    else
      render :new, status: :unprocessable_entity
    end
  end
end
