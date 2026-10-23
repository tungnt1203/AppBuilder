class ApplicationMailer < ActionMailer::Base
  # The address emails come from (MAIL_FROM, one the mail service sends for); a shop's go out in
  # its name, with replies to its own address.
  default from: -> { ENV.fetch("MAIL_FROM", "from@example.com") }
  layout "mailer"
  helper :mailer

  private
    def from_shop(shop)
      email_address_with_name(ENV.fetch("MAIL_FROM", "from@example.com"), shop.name)
    end
end
