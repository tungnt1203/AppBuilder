# Tells the owner and admins about a new order.
class Admin::OrderMailer < Admin::BaseMailer
  helper :money

  def placed(order)
    @order = order
    recipients = User.where(role: %w[ owner admin ]).pluck(:email_address)
    return if recipients.empty?

    mail to: recipients, subject: t(".subject", number: order.name, total: ApplicationController.helpers.money(order.total_cents, order.currency))
  end
end
