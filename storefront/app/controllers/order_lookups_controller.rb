# "Find my order": buyers check out without an account, so they find their orders by email. The
# shop emails a link (to show) listing their orders here, valid for a day; asking says the same
# whether or not the email has orders, so nobody learns who bought.
class OrderLookupsController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_order_lookup_path, alert: t("order_lookups.rate_limited") }

  def new
  end

  def create
    @email = params[:email].to_s.strip
    storefront.request_order_lookup(@email)
    redirect_to sent_order_lookup_path, flash: { lookup_email: @email }
  rescue StorefrontKit::Invalid => error
    @error = error.fields["email"] || error.message
    render :new, status: :unprocessable_entity
  rescue StorefrontKit::RateLimited
    redirect_to new_order_lookup_path, alert: t("order_lookups.rate_limited")
  end

  # Where asking lands (forms redirect, for Turbo); the email only shows right after asking.
  def sent
    @email = flash[:lookup_email]
  end

  def show
    @lookup = storefront.order_lookup(params[:token])
  rescue StorefrontKit::NotFound
    render :expired, status: :not_found
  end
end
