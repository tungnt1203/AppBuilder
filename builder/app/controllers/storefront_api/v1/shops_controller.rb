# The shop itself: name, currency, shipping, how buyers pay, pixels, policies, contact.
class StorefrontApi::V1::ShopsController < StorefrontApi::V1::BaseController
  def show
    render json: { shop: json.shop(current_shop, preview: api_key.preview?) }
  end
end
