# Tells the shop's owners and admins about a new order.
class Admin::OrderMailer < ApplicationMailer
  helper :money

  def placed(order)
    @order = order
    recipients = order.shop.memberships.where(role: %w[ owner admin ]).joins(:user).pluck("users.email_address")
    return if recipients.empty?

    mail to: recipients, subject: t(".subject", number: order.name, total: ApplicationController.helpers.money(order.total_cents, order.currency))
  end
end
