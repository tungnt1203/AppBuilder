# Policies, delivery and the buyer's profile.
class Agent::Storefront::InfosController < Agent::Storefront::BaseController
  def policies
    render json: { policies: catalog.policies(params[:query]) }
  end

  def fulfillment
    render json: { options: catalog.fulfillment(params[:product_ids]) }
  end

  def preferences
    render json: { user_id: customer ? "customer-#{customer.id}" : "guest", display_name: customer&.name, loyalty_tier: nil,
      default_location: nil, preferences: {}, signed_in: customer.present?, store: Rails.configuration.x.app_name, currency: store.currency }
  end
end
