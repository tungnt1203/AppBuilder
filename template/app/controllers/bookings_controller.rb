# Booking an appointment, one choice at a time on the same page (/book): the service, who with
# (when more than one person does it), the day, the time, then the customer's details. Each choice
# is a link that adds a parameter, so the back button and shared links work.
class BookingsController < ApplicationController
  DAYS_SHOWN = 14

  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to new_booking_path, alert: t("bookings.rate_limited") }

  before_action :require_booking

  def new
    @services = Service.bookable.ordered.includes(:staff_members)
    @service = @services.find_by(slug: params[:service]) if params[:service]
    choose_time(staff: params[:staff], date: params[:date], time: params[:time]) if @service
  end

  # When the time was taken meanwhile, the page shows the day's times again with the details kept.
  def create
    @booking = Booking.new(**booking_params)
    @booking.customer = Current.customer if customer_signed_in?

    if (appointment = @booking.place)
      redirect_to appointment_path(appointment, booked: 1)
    elsif (@service = @booking.service)
      @services = Service.bookable.ordered
      choose_time(staff: @booking.staff_member_id, date: @booking.starts_at&.in_time_zone&.to_date&.iso8601, time: @booking.starts_at&.iso8601)
      render :new, status: :unprocessable_entity
    else
      redirect_to new_booking_path
    end
  end

  private
    def choose_time(staff:, date:, time:)
      @staff_member = @service.staff_members.active.find_by(id: staff) if staff.present?
      @days = (Date.current...(Date.current + DAYS_SHOWN)).to_a
      @date = @days.find { |day| day.iso8601 == date } || @days.find { |day| slots_on(day).any? } || @days.first
      @slots = slots_on(@date)
      @starts_at = @slots.find { |slot| slot.starts_at.iso8601 == time }&.starts_at
      @booking ||= Booking.new(service_id: @service.id, staff_member_id: @staff_member&.id, starts_at: @starts_at, **prefill) if @starts_at
    end

    def slots_on(day)
      (@slots_by_day ||= {})[day] ||= Availability.new(@service, day, staff_member: @staff_member).slots
    end

    def booking_params
      params.expect(booking: %i[ service_id staff_member_id starts_at name email phone note ]).to_h.symbolize_keys
    end

    def prefill
      customer_signed_in? ? { name: Current.customer.name, email: Current.customer.email_address } : {}
    end
end
