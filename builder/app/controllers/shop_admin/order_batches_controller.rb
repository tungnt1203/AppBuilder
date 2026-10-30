# Several orders at once, ticked in the list: manual payments marked paid, paid orders put in
# production, shipped ones marked delivered. Each order that can't take the step is left as it is
# and counted, so staff see what's still to do.
class ShopAdmin::OrderBatchesController < ShopAdmin::BaseController
  STEPS = {
    "paid" => [ :can_mark_paid?, ->(order, user) { order.mark_paid!(by: user) } ],
    "in_production" => [ :can_start_production?, ->(order, user) { order.start_production!(by: user) } ],
    "delivered" => [ :can_mark_delivered?, ->(order, user) { order.mark_delivered!(by: user) } ]
  }.freeze

  def update
    orders = Order.where(token: Array(params[:order_tokens]))
    can, step = STEPS[params[:batch_action]]
    return redirect_back_or_to(shop_admin_orders_path, alert: t(".nothing")) if orders.none? || step.nil?

    done, left = orders.to_a.partition(&can)
    done.each { |order| step.call(order, Current.user) }
    notice = [ t(".#{params[:batch_action]}", count: done.size), (t(".left", count: left.size) if left.any?) ].compact.join(" ")
    redirect_back_or_to shop_admin_orders_path, notice:, status: :see_other
  end
end
