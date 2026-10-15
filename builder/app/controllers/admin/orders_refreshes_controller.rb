# "Refresh" on the owner's orders board: asks each of their selling apps again (ShopOrders).
class Admin::OrdersRefreshesController < ApplicationController
  def create
    Current.user.projects.listed.each { |project| OrdersRefreshJob.perform_later(project) if ShopOrders.new(project).applicable? }
    redirect_to admin_root_path, notice: "Asking your shops; refresh the page in a minute.", status: :see_other
  end
end
