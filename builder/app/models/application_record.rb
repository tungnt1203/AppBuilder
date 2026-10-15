class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  EMAIL_FORMAT = /\A[^@\s]+@[^@\s.]+(\.[^@\s.]+)*\.[a-z]{2,}\z/i
end
