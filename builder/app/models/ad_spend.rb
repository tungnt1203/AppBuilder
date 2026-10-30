# What the shop spent on ads one day for one source, as the owner enters it from their ad
# accounts: the same names Order#source gives (facebook, tiktok, google, or a link's utm_source),
# so ShopReport sets each source's sales against what it cost. Entering a day and source again
# replaces it.
class AdSpend < ApplicationRecord
  acts_as_tenant :shop

  include MoneyAttributes

  KNOWN_SOURCES = %w[ facebook tiktok google ].freeze

  money_attribute :amount

  normalizes :source, with: ->(source) { source.to_s.strip.downcase.gsub(/\s+/, "-") }

  validates :date, presence: true
  validates :source, presence: true, format: { with: /\A[\w.-]{1,40}\z/ }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :date_not_ahead

  scope :newest_first, -> { order(date: :desc, source: :asc) }

  # From the form: the day and source's row, new or replaced.
  def self.record(date:, source:, amount:)
    find_or_initialize_by(date:, source: normalize_value_for(:source, source)).tap { |spend| spend.update(amount:) }
  end

  # The sources to offer: the known ad networks, then any the shop's orders came from.
  def self.sources
    (KNOWN_SOURCES + Order.real.where.not(attribution: nil).distinct.pluck(Arel.sql("attribution->>'source'")).compact + distinct.pluck(:source)).uniq
  end

  private
    def date_not_ahead
      today = Time.current.in_time_zone(shop&.time_zone || "UTC").to_date
      errors.add(:date, :in_future) if date && date > today
    end
end
