# Buyers find their orders by email, without an account (OrderLookup). Asking answers the same
# whether or not the email has orders here, so nobody learns who bought; the shop emails the link
# only when there are some. A few asks a minute per email, so it can't be used to flood an inbox.
class StorefrontApi::V1::OrderLookupsController < StorefrontApi::V1::BaseController
  rate_limit to: 3, within: 10.minutes, name: "lookup", by: -> { "#{@api_key.id}:#{params[:email].to_s.strip.downcase}" },
    with: -> { error :rate_limited, "Too many requests for this email: try again in a few minutes", status: :too_many_requests }

  def create
    lookup = OrderLookup.new(params.expect(:email), test: api_key.preview?)
    return error(:invalid, "Enter a valid email", fields: { "email" => "isn't a valid email" }, status: :unprocessable_entity) unless lookup.valid?

    lookup.deliver_later
    render json: {}, status: :accepted
  end

  # The buyer's orders, by the token in the emailed link; 404 once it's expired.
  def show
    lookup = OrderLookup.from_token(params[:id]) or return error(:not_found, "This link has expired or isn't valid", status: :not_found)
    orders = lookup.orders.includes(line_items: { variant: { product: { images_attachments: :blob } } })
    render json: { order_lookup: { email: lookup.email, orders: orders.map { |order| json.order(order) } } }
  end
end
