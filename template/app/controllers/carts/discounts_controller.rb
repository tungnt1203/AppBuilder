# The discount code on the visitor's cart.
class Carts::DiscountsController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: :create, with: -> { redirect_to cart_path, alert: t("carts.discounts.rate_limited") }

  def create
    problem = current_cart ? current_cart.apply_discount_code(params[:code]) : :unknown

    if problem
      redirect_to cart_path, alert: t(problem, scope: "discounts.problems"), status: :see_other
    else
      redirect_to cart_path, notice: t(".notice"), status: :see_other
    end
  end

  def destroy
    current_cart&.remove_discount_code
    redirect_to cart_path, status: :see_other
  end
end
