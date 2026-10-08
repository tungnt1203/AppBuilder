# The calendar: a day's appointments (today by default), the upcoming ones, a search; staff book
# for customers who call or walk in, and keep notes on an appointment.
class Admin::AppointmentsController < Admin::BaseController
  before_action :require_booking
  before_action :set_appointment, only: %i[ show update ]

  def index
    if params[:q].present?
      @page = paginate(Appointment.search(params[:q]).order(starts_at: :desc).includes(:staff_member), per: 50)
    else
      @date = (Date.iso8601(params[:date]) rescue Date.current)
      @appointments = Appointment.on(@date).includes(:staff_member)
    end
  end

  def show
  end

  def new
    @booking = Booking.new(service_id: params[:service_id], staff_member_id: params[:staff_member_id],
      starts_at: params[:starts_at].presence && Time.zone.parse(params[:starts_at]))
  end

  def create
    @booking = Booking.new(**booking_params)
    @booking.by_staff = true

    if (appointment = @booking.place)
      redirect_to admin_appointment_path(appointment), notice: t(".notice", name: appointment.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @appointment.update(params.expect(appointment: %i[ staff_note phone ]))
      redirect_to admin_appointment_path(@appointment), notice: t(".notice")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_appointment
      @appointment = Appointment.find_by!(token: params[:id])
    end

    def booking_params
      params.expect(booking: %i[ service_id staff_member_id starts_at name email phone note ]).to_h.symbolize_keys
    end
end
