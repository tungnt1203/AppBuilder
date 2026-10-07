class Current < ActiveSupport::CurrentAttributes
  # The owner or staff member signed in to /admin.
  attribute :session
  delegate :user, to: :session, allow_nil: true

  # The customer signed in to the customers' site.
  attribute :customer_session
  delegate :customer, to: :customer_session, allow_nil: true
end
