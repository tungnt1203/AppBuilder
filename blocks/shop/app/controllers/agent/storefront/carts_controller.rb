# The agent's cart for its conversation. Lines are written by product id (a variant, or a
# product without options) and every write answers with the whole cart.
class Agent::Storefront::CartsController < Agent::Storefront::BaseController
  def show
    render json: catalog.cart_json(agent_cart)
  end

  # A buyer's browser takes the cart over at this link and goes on to checkout; it's only ever
  # given to the buyer, never to the model.
  def handoff
    cart = agent_cart
    return render(json: { handoffs: [] }) if cart.nil? || cart.empty?

    token = cart.signed_id(purpose: :agent_cart_claim, expires_in: 1.day)
    render json: { handoffs: [ { url: agent_cart_claim_url(token, **url_options_for_links), label: nil, seller: nil } ] }
  end
end
