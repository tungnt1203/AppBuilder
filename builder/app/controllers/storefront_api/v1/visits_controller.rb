# A storefront visitor got further in the shop today (Visit.reach!): { visitor, step, source }.
# Not counted from the builder's preview.
class StorefrontApi::V1::VisitsController < StorefrontApi::V1::BaseController
  def create
    unless api_key.preview?
      Visit.reach!(visitor: params.require(:visitor).to_s.first(64), step: params.require(:step), source: params[:source])
    end
    head :no_content
  rescue ArgumentError => problem
    error :invalid, problem.message, status: :unprocessable_entity
  end
end
