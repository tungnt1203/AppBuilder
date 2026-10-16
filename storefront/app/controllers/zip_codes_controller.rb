# Where a US ZIP code is, for checkout to fill in the city and state: { state:, city: }.
class ZipCodesController < ApplicationController
  def show
    place = storefront.zip_code(params[:id])
    expires_in 1.day, public: true
    place ? render(json: { state: place.region, city: place.city }) : head(:not_found)
  end
end
