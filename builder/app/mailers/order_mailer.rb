# Emails to the buyer about their order, from the shop, linking to its page on the storefront.
class OrderMailer < ApplicationMailer
  helper :money

  def confirmation(order)
    @order, @store = order, Store.current
    mail to: order.email, from: from_shop(order.shop), reply_to: @store.contact_email.presence,
      subject: t(".subject", app: order.shop.name, number: order.name)
  end

  def shipped(order)
    @order, @store = order, Store.current
    mail to: order.email, from: from_shop(order.shop), reply_to: @store.contact_email.presence,
      subject: t(".subject", app: order.shop.name, number: order.name)
  end

  def cancelled(order)
    @order, @store = order, Store.current
    mail to: order.email, from: from_shop(order.shop), reply_to: @store.contact_email.presence,
      subject: t(".subject", app: order.shop.name, number: order.name)
  end

  # The buyer left Stripe's payment page without paying: one reminder, with a link back to the
  # order, where they can pay.
  def recovery(order)
    @order, @store = order, Store.current
    mail to: order.email, from: from_shop(order.shop), reply_to: @store.contact_email.presence,
      subject: t(".subject", app: order.shop.name)
  end

  # A few days after the order arrived (Order::RequestReviewsJob): how do they like it? Links to
  # the order's review page.
  def review_request(order)
    @order, @store = order, Store.current
    @products = order.reviewable_products.with_attached_images.to_a
    return if @products.empty? # reviewed from the order page in the meantime
    mail to: order.email, from: from_shop(order.shop), reply_to: @store.contact_email.presence,
      subject: t(".subject", app: order.shop.name)
  end

  # The link to the buyer's orders at the shop, which they asked for by email (OrderLookup).
  def lookup(shop, email, token)
    @shop, @store = shop, Store.current
    @url = shop.storefront_url("/orders/find/#{token}")
    mail to: email, from: from_shop(shop), reply_to: @store.contact_email.presence, subject: t(".subject", app: shop.name)
  end

  def refunded(order)
    @order, @store = order, Store.current
    mail to: order.email, from: from_shop(order.shop), reply_to: @store.contact_email.presence,
      subject: t(".subject", app: order.shop.name, number: order.name)
  end
end
