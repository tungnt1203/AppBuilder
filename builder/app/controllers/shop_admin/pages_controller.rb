class ShopAdmin::PagesController < ShopAdmin::BaseController
  before_action :require_administrator
  before_action :set_page, only: %i[ edit update destroy ]

  def index
    @pages = ::Page.order(:title)
  end

  def new
    # ::Page: this controller includes Pagination, whose Page is the list struct.
    @page = ::Page.new
    @page.published = true
  end

  def create
    @page = ::Page.new(page_params)
    if @page.save
      redirect_to shop_admin_pages_path, notice: t(".notice", title: @page.title)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @page.update(page_params)
      redirect_to shop_admin_pages_path, notice: t(".notice", title: @page.title)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @page.destroy!
    redirect_to shop_admin_pages_path, notice: t(".notice", title: @page.title), status: :see_other
  end

  private
    def set_page
      @page = ::Page.find_by!(slug: params[:id])
    end

    def page_params
      params.expect(page: [ :title, :slug, :body, :published, faqs: [ [ :question, :answer ] ] ])
    end
end
