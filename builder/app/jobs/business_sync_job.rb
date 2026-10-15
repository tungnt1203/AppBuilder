# Applies the owner's business settings to one shop (BusinessSync); one job per shop, so a slow
# answer from Stripe or Printify for one doesn't hold the others back.
class BusinessSyncJob < ApplicationJob
  def perform(shop, user)
    BusinessSync.new(shop, user.business_setting).call if user.business_setting
  end
end
