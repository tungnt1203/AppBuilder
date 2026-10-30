# What the shop spent on ads, a day and a source at a time (AdSpend), for the dashboard's return
# on ad spend and profit after ads.
class ShopAdmin::AdSpendsController < ShopAdmin::BaseController
  def index
    @ad_spend = AdSpend.new(date: Time.current.in_time_zone(current_shop.time_zone).to_date - 1, source: "facebook")
    @page = paginate(AdSpend.newest_first, per: 60)
  end

  def create
    @ad_spend = AdSpend.record(**params.expect(ad_spend: %i[ date source amount ]).to_h.symbolize_keys)

    if @ad_spend.persisted? && @ad_spend.errors.none?
      redirect_to shop_admin_ad_spends_path, notice: t(".notice", amount: helpers.money(@ad_spend.amount_cents), source: @ad_spend.source, date: l(@ad_spend.date, format: :long))
    else
      @page = paginate(AdSpend.newest_first, per: 60)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    AdSpend.find(params[:id]).destroy!
    redirect_to shop_admin_ad_spends_path, notice: t(".notice"), status: :see_other
  end
end
