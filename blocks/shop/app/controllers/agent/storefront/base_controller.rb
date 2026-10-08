# For shopping agents acting for one buyer. The agent's host names its conversation in the
# X-Agent-Session header (its cart) and, when it has signed the buyer in, the customer's email in
# X-Agent-Customer (their orders). Both are trusted because the key is.
class Agent::Storefront::BaseController < Agent::BaseController
  private
    def agent_role = "storefront"

    def catalog
      @catalog ||= AgentApi::Catalog.new(url_options: url_options_for_links)
    end

    def session_key
      request.headers["X-Agent-Session"].presence or raise ActionController::ParameterMissing, "X-Agent-Session header"
    end

    def agent_cart
      Cart.find_by(agent_session_key: Digest::SHA256.hexdigest(session_key))
    end

    def agent_cart!
      agent_cart || Cart.create!(agent_session_key: Digest::SHA256.hexdigest(session_key))
    rescue ActiveRecord::RecordNotUnique
      agent_cart
    end

    def customer
      email = request.headers["X-Agent-Customer"].presence
      Customer.find_by(email_address: email.strip.downcase) if email && Rails.configuration.x.customer_accounts
    end
end
