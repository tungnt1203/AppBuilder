class Admin::ServicesController < Admin::BaseController
  before_action :require_booking
  before_action :set_service, only: %i[ show edit update destroy ]

  def index
    @services = Service.ordered.includes(:staff_members)
  end

  def show
    redirect_to edit_admin_service_path(@service)
  end

  def new
    @service = Service.new(staff_members: StaffMember.active.ordered)
  end

  def create
    @service = Service.new(service_params)

    if @service.save
      redirect_to admin_services_path, notice: t(".notice", name: @service.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to admin_services_path, notice: t(".notice", name: @service.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Appointments keep the service's name and price; they lose the link to it.
  def destroy
    @service.destroy!
    redirect_to admin_services_path, notice: t(".notice", name: @service.name), status: :see_other
  end

  private
    def set_service
      @service = Service.find_by!(slug: params[:id])
    end

    def service_params
      params.expect(service: [ :name, :description, :duration_minutes, :price, :status, :position, staff_member_ids: [] ])
    end
end
