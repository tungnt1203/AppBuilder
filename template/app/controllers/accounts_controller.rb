# The signed-in customer's own account: their details, and later their orders.
class AccountsController < ApplicationController
  before_action :require_customer

  def show
    @customer = Current.customer
  end

  def edit
    @customer = Current.customer
  end

  def update
    @customer = Current.customer

    if @customer.update(account_params)
      redirect_to account_path, notice: t(".notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    # A new password needs the current one (password_challenge); name and email don't.
    def account_params
      permitted = params.expect(customer: [ :name, :email_address, :password, :password_challenge ])
      permitted[:password].blank? ? permitted.except(:password, :password_challenge) : permitted
    end
end
