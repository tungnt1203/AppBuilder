# Brings an app's orders at a glance into the builder (ShopOrders). Without a project, every
# selling app's, as the recurring refresh of the owners' orders boards.
class OrdersRefreshJob < ApplicationJob
  def perform(project = nil)
    return ShopOrders.new(project).refresh if project

    Project.listed.where(status: %w[ ready working ]).find_each { |each| OrdersRefreshJob.perform_later(each) if ShopOrders.new(each).applicable? }
  end
end
