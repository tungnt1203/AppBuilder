# A booked appointment. The service's name and price are copied in, so it stays as it was booked
# when the service changes later. The customer reaches it by its token (appointment_path), from
# the confirmation and the emails; staff in /admin/appointments.
#
# Status moves with the methods below: booked → completed or no_show, or cancelled (by the
# customer, up to cancel_notice_hours before, or by staff at any time).
class Appointment < ApplicationRecord
  include MoneyAttributes

  STATUSES = %w[ booked completed no_show cancelled ].freeze

  belongs_to :service, optional: true
  belongs_to :staff_member, optional: true
  belongs_to :customer, optional: true

  has_secure_token :token, length: 32
  enum :status, STATUSES.index_by(&:itself), default: "booked"

  money_attribute :price

  validates :starts_at, :ends_at, :service_name, :name, presence: true
  validates :email, presence: true, format: { with: EMAIL_FORMAT }, length: { maximum: 254 }
  validates :name, :phone, length: { maximum: 200 }
  validates :note, :staff_note, length: { maximum: 2000 }
  validates :currency, inclusion: { in: Store::CURRENCIES.keys }
  validate :ends_after_start
  validate :staff_member_is_free, if: -> { booked? && (new_record? || will_save_change_to_starts_at? || will_save_change_to_staff_member_id?) }

  normalizes :email, with: ->(email) { email.strip.downcase }

  scope :overlapping, ->(range) { where(starts_at: ...range.end).where("appointments.ends_at > ?", range.begin) }
  scope :on, ->(date) { where(starts_at: date.in_time_zone.all_day).order(:starts_at) }
  scope :upcoming, -> { booked.where(starts_at: Time.current..).order(:starts_at) }
  scope :search, ->(query) {
    like = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("appointments.name LIKE :like OR appointments.email LIKE :like OR appointments.phone LIKE :like", like:) if query.present?
  }

  def to_param
    token
  end

  def duration_minutes
    ((ends_at - starts_at) / 60).round
  end

  def past?
    starts_at < Time.current
  end

  def cancellable_by_customer?(settings = BookingSetting.current)
    booked? && starts_at > settings.cancel_notice_hours.hours.from_now
  end

  def can_complete? = booked?
  def can_mark_no_show? = booked?
  def can_cancel? = booked?

  # by: "customer" or "staff". Sends the emails the other side needs.
  def cancel!(by:)
    transition! :cancelled, from: :can_cancel?, cancelled_at: Time.current, cancelled_by: by.to_s
    AppointmentMailer.cancelled(self).deliver_later
    Admin::AppointmentMailer.cancelled(self).deliver_later if by.to_s == "customer"
  end

  def complete!
    transition! :completed, from: :can_complete?
  end

  def mark_no_show!
    transition! :no_show, from: :can_mark_no_show?
  end

  class InvalidTransition < StandardError; end

  private
    def transition!(status, from:, **attributes)
      transaction do
        lock!
        raise InvalidTransition, "This appointment can't become #{status} while #{self.status}" unless public_send(from)
        update!(status:, **attributes)
      end
    end

    def ends_after_start
      errors.add(:ends_at, :before_start) if starts_at && ends_at && ends_at <= starts_at
    end

    # Two bookings for the same staff member at the same time: the second one fails. Runs inside
    # the booking's transaction, which SQLite gives to one writer at a time.
    def staff_member_is_free
      return unless staff_member_id && starts_at && ends_at

      taken = Appointment.booked.where(staff_member_id:).where.not(id:).overlapping(starts_at...ends_at).exists?
      errors.add(:starts_at, :taken) if taken
    end

  Bookings.extend_model(self)
end
