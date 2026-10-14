# Printify tells the shop here when an order ships, arrives or changes (registered by
# Store#register_printify_webhooks! when the shop has a public https address). The body only says
# which order: the shop asks Printify itself what happened (Printify::Fulfillment#sync!), so a
# forged or replayed call can't ship anything. Without webhooks, the hourly check does the same.
class PrintifyWebhooksController < ActionController::Base
  skip_forgery_protection

  def create
    store = Store.current
    secret = store.printify_signing_secret or return head(:not_found)
    return head(:unauthorized) unless PrintifyGateway.valid_signature?(request.raw_post, request.headers["X-Pfy-Signature"], secret)

    event = JSON.parse(request.raw_post)
    resource = event["resource"].to_h
    if event["type"].to_s.start_with?("order:") && (order = Order.find_by(printify_order_id: resource["id"].to_s.presence))
      Printify::Fulfillment.new(order, store).sync!
    end
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end
end
