class Agent::Merchant::ListingsController < Agent::Merchant::BaseController
  def index
    render json: { listings: merchant.search_listings(**params.permit(:query, :status, :max_stock, :sort, :limit).to_h.symbolize_keys) }
  end

  def show
    listing = merchant.listing(params[:id]) or raise ActiveRecord::RecordNotFound, "No listing #{params[:id]}"
    render json: listing
  end

  def pricing
    context = merchant.pricing(params[:id]) or raise ActiveRecord::RecordNotFound, "No listing #{params[:id]}"
    render json: context
  end
end
