class ShopAdmin::Forms::SubmissionsController < ShopAdmin::BaseController
  before_action :require_administrator

  def show
    @shop_form = Form.find_by!(key: params[:form_id])
    @submission = @shop_form.submissions.find(params[:id])
  end
end
