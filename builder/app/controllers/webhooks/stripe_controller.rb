# Stripe tells a shop about its card payments here (Store#register_stripe_webhook!). Most are
# already confirmed when the storefront shows the buyer their order (Order#sync_card_payment!);
# this catches the rest: buyers who closed the tab, payments that clear later, refunds made in
# the Stripe dashboard. An unpaid order is left to Order::ExpireUnpaidCardJob.
class Webhooks::StripeController < Webhooks::BaseController
  def create
    secret = store.stripe_signing_secret or return head(:not_found)
    event = StripeGateway.event(request.raw_post, request.headers["Stripe-Signature"], secret)
    WebhookEvent.handle(provider: "stripe", event_id: event.id, kind: event.type, payload: event.to_hash) { handle(event) }
    head :ok
  rescue StripeGateway::Error
    head :bad_request
  end

  private
    # Returns the order the event changed, if any.
    def handle(event)
      object = event.data.object

      case event.type
      when "payment_intent.succeeded"
        order = order_for(object)
        order if order&.confirm_card_payment!(payment_intent: object.id, gateway: store.stripe)
      when "charge.refunded"
        order = Order.find_by(payment_method: "stripe", payment_reference: object.payment_intent)
        if order&.can_refund? && object.refunded
          order.tap { order.refund!(reason: "Refunded in Stripe", stripe: false) }
        elsif order&.can_refund?
          order.tap { order.record_partial_refund!(StripeGateway.cents(object.amount_refunded, object.currency)) }
        end
      end
      # payment_intent.payment_failed: the buyer can try another card on the same order.
    end

    # The shop's order by its PaymentIntent, or by its id when the PaymentIntent says it's this
    # shop's (Store#uid) and wasn't saved on the order. Order ids alone repeat from shop to shop.
    def order_for(intent)
      Order.find_by(stripe_payment_intent_id: intent.id) ||
        (Order.find_by(id: intent.metadata&.[](:order_id), payment_method: "stripe", stripe_payment_intent_id: nil) if intent.metadata&.[](:shop) == store.uid)
    end
end
