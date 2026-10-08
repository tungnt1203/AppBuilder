# Sales: prices lowered for a while, started and ended on time by Promotion::SyncJob.
class Admin::PromotionsController < Admin::BaseController
  def index
    @promotions = Promotion.ordered.includes(variants: :product)
  end

  def new
    @promotion = Promotion.new(percent_off: 20, starts_at: Time.current.beginning_of_hour + 1.hour, ends_at: 7.days.from_now.end_of_day.change(sec: 0))
  end

  # Starts right away when it's already time.
  def create
    @promotion = Promotion.new(promotion_params)

    if @promotion.save
      @promotion.start!
      redirect_to admin_promotions_path, notice: t(".notice", name: @promotion.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def promotion_params
      params.expect(promotion: [ :name, :percent_off, :starts_at, :ends_at, variant_ids: [] ])
    end
end
