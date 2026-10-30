# The shop's demo products made again for its own kind (DemoCatalog::Niche from its project's first
# request, their photos drawn with its words), replacing the ones it has: for a shop made before
# demo products were its kind, or whose kind has changed. Without a usable reply, the static set.
class DemoCatalog::RefreshJob < ApplicationJob
  def perform(shop)
    niche = DemoCatalog::Niche.for(shop.project&.messages&.user&.first&.body)
    ActsAsTenant.with_tenant(shop) do
      DemoCatalog.remove!
      DemoCatalog.add!(niche:)
    end
  end
end
