class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # An email address that can receive mail: a name, @, and a domain with a dot
  # (URI::MailTo::EMAIL_REGEXP also lets "pat@gmail" through, which Stripe and mail servers refuse).
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s.]+(\.[^@\s.]+)*\.[a-z]{2,}\z/i
end
