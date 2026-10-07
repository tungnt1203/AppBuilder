# Preview all emails at http://localhost:3000/rails/mailers/order_mailer
class OrderMailerPreview < ActionMailer::Preview
  def confirmation
    OrderMailer.confirmation(Order.last || raise("Place an order first (bin/rails db:seed, then check out)"))
  end

  def shipped
    OrderMailer.shipped(Order.where.not(tracking_number: nil).last || Order.last)
  end
end
