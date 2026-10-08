# A staff member's hours on one day of the week, in minutes from midnight in the app's time zone
# (9:00 is 540). Edited as "9:00" and "17:30" (opens_at_text, closes_at_text).
class WorkingHour < ApplicationRecord
  belongs_to :staff_member, inverse_of: :working_hours

  validates :weekday, inclusion: { in: StaffMember::WEEKDAYS }
  validates :opens_at, :closes_at, numericality: { only_integer: true, in: 0..(24 * 60) }
  validate :times_make_sense

  # "9", "9:00", "17.30", "9h30", "5:30 pm" → minutes from midnight; nil when it isn't a time.
  def self.parse_time(text)
    match = text.to_s.strip.match(/\A(\d{1,2})(?:[:.h](\d{2}))?\s*(am|pm)?\z/i) or return
    hours, minutes, meridian = match[1].to_i, match[2].to_i, match[3]&.downcase
    hours = hours % 12 + (meridian == "pm" ? 12 : 0) if meridian
    total = hours * 60 + minutes
    total if minutes < 60 && total <= 24 * 60
  end

  def self.format_time(minutes)
    format("%d:%02d", minutes / 60, minutes % 60) if minutes
  end

  %i[ opens_at closes_at ].each do |name|
    define_method("#{name}_text") { self.class.format_time(public_send(name)) }
    define_method("#{name}_text=") do |text|
      public_send("#{name}=", self.class.parse_time(text))
      errors_on_parse[name] = text if text.present? && public_send(name).nil?
    end
  end

  private
    def errors_on_parse
      @errors_on_parse ||= {}
    end

    def times_make_sense
      errors_on_parse.each_key { |name| errors.add(:"#{name}_text", :invalid) }
      errors.add(:closes_at_text, :before_opening) if opens_at && closes_at && closes_at <= opens_at
    end

  Bookings.extend_model(self)
end
