class ShopAdmin::Orders::ShipmentsController < ShopAdmin::BaseController
  include ShopAdmin::OrderTransition

  def create
    transition do
      @order.ship!(carrier: params[:carrier], tracking_number: params[:tracking_number], tracking_url: params[:tracking_url], by: Current.user)
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to shop_admin_order_path(@order), alert: @order.errors.full_messages.to_sentence, status: :see_other
  end
end
