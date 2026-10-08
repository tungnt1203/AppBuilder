# Ends a sale early (or calls off one that hasn't started), putting the prices back.
class Admin::Promotions::CancellationsController < Admin::BaseController
  def create
    promotion = Promotion.find(params[:promotion_id])
    promotion.cancel!
    redirect_to admin_promotions_path, notice: t(".notice", name: promotion.name), status: :see_other
  end
end
