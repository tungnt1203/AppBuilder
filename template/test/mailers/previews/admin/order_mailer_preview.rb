# Preview all emails at http://localhost:3000/rails/mailers/admin/order_mailer
class Admin::OrderMailerPreview < ActionMailer::Preview
  def placed
    Admin::OrderMailer.placed(Order.last)
  end
end
