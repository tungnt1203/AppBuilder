# Where a US ZIP code is, for checkout to fill in the city and state (ZipCode): { state:, city: }.
class ZipCodesController < ApplicationController
  def show
    place = ZipCode.lookup(params[:id])
    expires_in 1.day, public: true
    place ? render(json: place) : head(:not_found)
  end
end
