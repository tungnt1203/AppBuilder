# Where a buyer's browser takes over the cart a shopping agent filled for them (the link from
# Agent::Storefront::CartsController#handoff), then goes on to checkout.
class Agent::CartClaimsController < ActionController::Base
  def show
    cart = Cart.find_signed(params[:token], purpose: :agent_cart_claim) or return redirect_to(cart_path, alert: I18n.t("agent_api.claim_expired"))
    cookies.signed.permanent[:cart_id] = { value: cart.id, httponly: true, same_site: :lax }
    redirect_to new_checkout_path
  end
end
