class ShopAdmin::FormsController < ShopAdmin::BaseController
  before_action :require_administrator
  before_action :set_form, only: %i[ edit update destroy ]

  def index
    @forms = Form.order(:title).left_joins(:submissions).group(:id).select("forms.*, COUNT(form_submissions.id) AS submissions_count")
  end

  def new
    @shop_form = Form.new
  end

  def create
    @shop_form = Form.new(form_params)
    if @shop_form.save
      redirect_to edit_shop_admin_form_path(@shop_form), notice: t(".notice", title: @shop_form.title)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @submissions = @shop_form.submissions.newest.limit(20)
  end

  def update
    if @shop_form.update(form_params)
      redirect_to edit_shop_admin_form_path(@shop_form), notice: t(".notice", title: @shop_form.title)
    else
      @submissions = @shop_form.submissions.newest.limit(20)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shop_form.destroy!
    redirect_to shop_admin_forms_path, notice: t(".notice", title: @shop_form.title), status: :see_other
  end

  private
    def set_form
      @shop_form = Form.find_by!(key: params[:id])
    end

    def form_params
      params.expect(form: [ :key, :title, fields: [ [ :key, :label, :type, :required ] ] ])
    end
end
