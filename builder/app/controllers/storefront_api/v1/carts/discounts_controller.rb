# The discount code a buyer enters in the cart: kept when it can be used on the cart now, else a
# 422 saying why (unknown, expired, not_started, used_up, below_minimum).
class StorefrontApi::V1::Carts::DiscountsController < StorefrontApi::V1::Carts::BaseController
  def create
    if (problem = @cart.apply_discount_code(params.require(:code)))
      error problem, I18n.t("discounts.problems.#{problem}"), fields: { "code" => I18n.t("discounts.problems.#{problem}") }, status: :unprocessable_entity
    else
      render_cart
    end
  end

  def destroy
    @cart.remove_discount_code
    render_cart
  end
end
