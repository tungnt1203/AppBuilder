# A buyer's photo for a personalized product, sent from the product page as they pick it (the
# personalize controller) and kept on the Platform. Answers with its token, for the line's
# properties, and its size, to warn about a photo too small to print well.
class UploadsController < ApplicationController
  rate_limit to: 20, within: 10.minutes, only: :create

  def create
    upload = storefront.upload(params.require(:photo))
    render json: { token: upload.token, width: upload.width, height: upload.height }, status: :created
  rescue StorefrontKit::Invalid => error
    render json: { error: error.fields.values.first || error.message }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing
    render json: { error: t(".missing") }, status: :bad_request
  end
end
