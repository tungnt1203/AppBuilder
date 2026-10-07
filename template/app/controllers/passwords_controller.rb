# Customers reset a forgotten password by email.
class PasswordsController < ApplicationController
  before_action :require_customer_accounts
  before_action :set_customer_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: t("passwords.rate_limited") }

  def new
  end

  def create
    if customer = Customer.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(customer).deliver_later
    end

    redirect_to new_session_path, notice: t(".notice")
  end

  def edit
  end

  def update
    if @customer.update(params.permit(:password, :password_confirmation))
      @customer.sessions.destroy_all
      redirect_to new_session_path, notice: t(".notice")
    else
      redirect_to edit_password_path(params[:token]), alert: @customer.errors.full_messages.to_sentence
    end
  end

  private
    def set_customer_by_token
      @customer = Customer.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: t("passwords.invalid")
    end
end
