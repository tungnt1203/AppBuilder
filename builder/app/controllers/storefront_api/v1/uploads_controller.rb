# A buyer's photo for a personalized product (BuyerUpload), sent as multipart form data ("photo").
# Answers with its token, for the cart line's properties, its size and where to show it.
class StorefrontApi::V1::UploadsController < StorefrontApi::V1::BaseController
  rate_limit to: 30, within: 10.minutes, by: -> { [ @api_key.id, request.remote_ip ].join(":") },
    with: -> { error :rate_limited, "Too many photos: wait a few minutes", status: :too_many_requests }

  def create
    upload = BuyerUpload.take(params.require(:photo))
    return invalid(upload) unless upload.persisted?

    render json: { upload: json.upload(upload) }, status: :created
  end
end
