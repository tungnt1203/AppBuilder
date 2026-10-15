# One of the shop's policies (refund, shipping, privacy, terms) as the owner wrote it; the ones
# it has are listed in /v1/shop.
class StorefrontApi::V1::PoliciesController < StorefrontApi::V1::BaseController
  def show
    raise ActiveRecord::RecordNotFound.new(nil, "Policy") unless store.policy(params[:id].to_s)

    render json: { policy: json.policy(params[:id].to_s) }
  end
end
