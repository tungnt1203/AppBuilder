# Emails to the buyer about their order.
class OrderMailer < ApplicationMailer
  helper :money

  def confirmation(order)
    @order, @store = order, Store.current
    mail to: order.email, reply_to: @store.contact_email.presence,
      subject: t(".subject", app: Rails.configuration.x.app_name, number: order.name)
  end

  def shipped(order)
    @order, @store = order, Store.current
    mail to: order.email, reply_to: @store.contact_email.presence,
      subject: t(".subject", app: Rails.configuration.x.app_name, number: order.name)
  end
end
