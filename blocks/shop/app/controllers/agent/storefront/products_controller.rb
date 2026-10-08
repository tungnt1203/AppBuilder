class Agent::Storefront::ProductsController < Agent::Storefront::BaseController
  def index
    render json: { products: catalog.search(**params.permit(:query, :category, :min_price, :max_price, :sort, :limit).to_h.symbolize_keys) }
  end

  def show
    details = catalog.details(params[:id]) or raise ActiveRecord::RecordNotFound, "No product #{params[:id]}"
    render json: details
  end
end
