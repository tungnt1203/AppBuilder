# The people (or chairs, rooms) customers book, the services they do and their weekly hours.
class Admin::StaffMembersController < Admin::BaseController
  before_action :require_booking
  before_action :set_staff_member, only: %i[ show edit update destroy ]

  def index
    @staff_members = StaffMember.ordered.includes(:services, :working_hours)
  end

  def show
    redirect_to edit_admin_staff_member_path(@staff_member)
  end

  def new
    @staff_member = StaffMember.new(services: Service.ordered)
  end

  def create
    @staff_member = StaffMember.new(staff_member_params)

    if @staff_member.save
      redirect_to edit_admin_staff_member_path(@staff_member), notice: t(".notice", name: @staff_member.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @staff_member.update(staff_member_params)
      redirect_to edit_admin_staff_member_path(@staff_member), notice: t(".notice", name: @staff_member.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Their appointments stay, without anyone assigned.
  def destroy
    @staff_member.destroy!
    redirect_to admin_staff_members_path, notice: t(".notice", name: @staff_member.name), status: :see_other
  end

  private
    def set_staff_member
      @staff_member = StaffMember.find(params[:id])
    end

    def staff_member_params
      params.expect(staff_member: [ :name, :bio, :active, :position, :photo, service_ids: [],
        working_hours_attributes: [ [ :id, :weekday, :opens_at_text, :closes_at_text, :_destroy ] ] ])
    end
end
