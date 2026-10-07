class PasswordsMailer < ApplicationMailer
  def reset(customer)
    @customer = customer
    mail subject: t(".subject", app: Rails.configuration.x.app_name), to: customer.email_address
  end
end
