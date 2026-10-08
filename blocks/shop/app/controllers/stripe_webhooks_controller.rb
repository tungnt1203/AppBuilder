# Stripe tells the shop about payments here (registered by Store#connect_stripe! when the shop
# has a public https address). Most card payments are already confirmed when the buyer comes
# back to the order page; this catches the rest: buyers who closed the tab, payments that
# clear later, Checkout sessions that expired, refunds made in the Stripe dashboard.
class StripeWebhooksController < ActionController::Base
  skip_forgery_protection

  def create
    store = Store.current
    secret = store.stripe_signing_secret or return head(:not_found)
    event = StripeGateway.event(request.raw_post, request.headers["Stripe-Signature"], secret)
    handle event
    head :ok
  rescue StripeGateway::Error
    head :bad_request
  end

  private
    def handle(event)
      object = event.data.object

      case event.type
      when "checkout.session.completed", "checkout.session.async_payment_succeeded"
        if object.payment_status == "paid" && (order = order_for(object))
          order.confirm_card_payment!(payment_intent: object.payment_intent, tax_cents: StripeGateway.tax_cents(object))
        end
      when "checkout.session.async_payment_failed", "checkout.session.expired"
        order = order_for(object)
        order.cancel!(reason: "Payment not completed", notify: false) if order&.pending? && order.stripe_checkout_session_id == object.id
      when "charge.refunded"
        order = Order.find_by(payment_method: "stripe", payment_reference: object.payment_intent)
        order.refund!(reason: "Refunded in Stripe", stripe: false) if order&.can_refund? && object.refunded
      end
    end

    def order_for(session)
      Order.find_by(stripe_checkout_session_id: session.id) || Order.find_by(id: session.metadata&.[](:order_id), payment_method: "stripe")
    end
end
