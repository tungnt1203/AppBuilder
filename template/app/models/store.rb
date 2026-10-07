# The shop's settings, one row: currency, shipping rates, where it ships, how to pay.
# Store.current everywhere; the owner changes it at /admin/settings.
class Store < ApplicationRecord
  include MoneyAttributes

  # Currencies the shop can sell in, with how prices are written.
  CURRENCIES = {
    "USD" => { unit: "$", precision: 2 },
    "EUR" => { unit: "€", precision: 2 },
    "GBP" => { unit: "£", precision: 2 },
    "CAD" => { unit: "CA$", precision: 2 },
    "AUD" => { unit: "A$", precision: 2 },
    "VND" => { unit: "₫", precision: 0, format: "%n %u" }
  }.freeze

  money_attribute :shipping_first_item, :shipping_additional_item, :free_shipping_threshold

  validates :currency, inclusion: { in: CURRENCIES.keys }
  validates :shipping_first_item_cents, :shipping_additional_item_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :free_shipping_threshold_cents, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :countries_are_known

  normalizes :ship_to_countries, with: ->(codes) { Array(codes).map { |code| code.to_s.strip.upcase }.compact_blank.uniq.sort }

  def self.current
    first || create!
  end

  # Flat-rate shipping: one price for the first item, another for each one after it, free above
  # the threshold.
  def shipping_cents_for(item_count:, subtotal_cents:)
    return 0 if item_count.zero?
    return 0 if free_shipping_threshold_cents && subtotal_cents >= free_shipping_threshold_cents

    shipping_first_item_cents + shipping_additional_item_cents * (item_count - 1)
  end

  # Empty means anywhere.
  def ships_to?(country)
    ship_to_countries.empty? || ship_to_countries.include?(country.to_s.upcase)
  end

  def countries_for_checkout
    codes = ship_to_countries.presence || Country.codes
    Country.options(codes)
  end

  def ship_to_countries_text
    ship_to_countries.join(", ")
  end

  def ship_to_countries_text=(text)
    self.ship_to_countries = text.to_s.split(/[\s,]+/)
  end

  def money_format
    CURRENCIES.fetch(currency)
  end

  private
    def countries_are_known
      unknown = ship_to_countries - Country.codes
      errors.add(:ship_to_countries, :unknown, codes: unknown.join(", ")) if unknown.any?
    end
end
