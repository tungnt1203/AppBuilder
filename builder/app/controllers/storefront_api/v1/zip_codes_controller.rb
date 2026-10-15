# Where a US ZIP code is, for checkout to fill in the city and state as the buyer types it.
class StorefrontApi::V1::ZipCodesController < StorefrontApi::V1::BaseController
  def show
    place = ZipCode.lookup(params[:id]) or raise ActiveRecord::RecordNotFound.new(nil, "ZipCode")
    render json: { zip_code: { zip: params[:id].to_s.first(5), country: "US", region: place[:state], city: place[:city] } }
  end
end
