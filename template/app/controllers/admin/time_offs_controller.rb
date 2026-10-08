# Holidays and closures: a staff member's time off, or the whole business closed.
class Admin::TimeOffsController < Admin::BaseController
  before_action :require_booking

  def index
    @time_offs = TimeOff.upcoming.includes(:staff_member)
  end

  def new
    @time_off = TimeOff.new(starts_at: Date.tomorrow.beginning_of_day, ends_at: Date.tomorrow.end_of_day.change(sec: 0))
  end

  def create
    @time_off = TimeOff.new(params.expect(time_off: %i[ staff_member_id starts_at ends_at reason ]))

    if @time_off.save
      redirect_to admin_time_offs_path, notice: t(".notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    TimeOff.find(params[:id]).destroy!
    redirect_to admin_time_offs_path, notice: t(".notice"), status: :see_other
  end
end
