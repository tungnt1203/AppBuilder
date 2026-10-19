# Printify tells a shop here when an order ships, arrives or changes (Store#register_printify_webhooks!).
# The body only says which order: the shop asks Printify itself what happened
# (Printify::Fulfillment#sync!), so a forged or replayed call can't ship anything. Without
# webhooks, the hourly check does the same.
class Webhooks::PrintifyController < Webhooks::BaseController
  def create
    secret = store.printify_signing_secret or return head(:not_found)
    return head(:unauthorized) unless PrintifyGateway.valid_signature?(request.raw_post, request.headers["X-Pfy-Signature"], secret)

    event = JSON.parse(request.raw_post)
    return head(:bad_request) unless event.is_a?(Hash) && event["id"].present?

    WebhookEvent.handle(provider: "printify", event_id: event["id"], kind: event["type"].to_s.presence || "unknown", payload: event) { handle(event) }
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private
    # Returns the order the event is about, if it's one of the shop's.
    def handle(event)
      return unless event["type"].to_s.start_with?("order:")

      order = Order.find_by(printify_order_id: event.dig("resource", "id").to_s.presence)
      order&.tap { Printify::Fulfillment.new(order, store).sync! }
    end
end
