# Turns what a visitor picked (a service, a time, maybe a staff member) and their details into an
# Appointment. The time is checked against Availability again when it's placed, in the same
# transaction, and the service's name, duration and price come from the database, never from the
# form. Staff booking for a customer (/admin) skip the booking notice and the days-ahead limit.
class Booking
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :service_id, :integer
  attribute :staff_member_id, :integer # nil: whoever is free
  attribute :starts_at, :datetime
  attribute :name, :string
  attribute :email, :string
  attribute :phone, :string
  attribute :note, :string

  attr_reader :appointment
  attr_accessor :customer, :by_staff

  validates :service, presence: true
  validates :starts_at, :name, presence: true
  validates :email, presence: true, format: { with: ApplicationRecord::EMAIL_FORMAT }
  validate :time_is_free

  # A time from a form ("2026-10-09T09:00", or ISO 8601 with its offset) is in the app's time zone.
  def starts_at=(value)
    super(value.is_a?(String) ? Time.zone.parse(value) : value)
  rescue ArgumentError
    super(nil)
  end

  def self.human_attribute_name(attribute, options = {})
    Appointment.human_attribute_name(attribute, options)
  end

  def service
    @service ||= Service.find_by(id: service_id) if service_id
  end

  def staff_member
    @staff_member ||= StaffMember.active.find_by(id: staff_member_id) if staff_member_id
  end

  # Books the appointment. Returns it, or nil with errors on the booking.
  def place
    ActiveRecord::Base.transaction do
      next unless valid?

      @appointment = Appointment.create!(service:, staff_member: free_staff_members.first, customer:,
        starts_at:, ends_at: starts_at + service.duration, service_name: service.name,
        price_cents: service.price_cents, currency: Store.current.currency,
        name:, email:, phone:, note:)
    end
    return unless @appointment

    AppointmentMailer.confirmation(@appointment).deliver_later
    Admin::AppointmentMailer.booked(@appointment).deliver_later unless by_staff
    @appointment
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.each { |record_error| errors.add(record_error.attribute, record_error.message) }
    nil
  end

  private
    def free_staff_members
      @free_staff_members ||= begin
        free = Availability.new(service, starts_at.in_time_zone.to_date, staff_member:, ignore_notice: by_staff).staff_free_at(starts_at)
        staff_member_id && !staff_member ? [] : free
      end
    end

    def time_is_free
      return unless service && starts_at

      errors.add(:starts_at, :taken) if free_staff_members.empty?
    end
end
