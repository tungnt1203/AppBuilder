# Applies the owner's business settings to one app (BusinessSync); one job per app, so a slow or
# broken app doesn't hold the others back.
class BusinessSyncJob < ApplicationJob
  def perform(project)
    BusinessSync.new(project).call
  end
end
