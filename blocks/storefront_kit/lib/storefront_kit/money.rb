require "bigdecimal"

module StorefrontKit
  # How the shop's currency is written: "$24.00", "24.000 ₫".
  module Money
    FORMATS = {
      "USD" => { unit: "$", precision: 2 },
      "EUR" => { unit: "€", precision: 2 },
      "GBP" => { unit: "£", precision: 2 },
      "CAD" => { unit: "CA$", precision: 2 },
      "AUD" => { unit: "A$", precision: 2 },
      "VND" => { unit: "₫", precision: 0, format: "%n %u" }
    }.freeze

    def self.format_for(currency) = FORMATS.fetch(currency.to_s) { { unit: "#{currency} ", precision: 2 } }

    # "24.00 USD", how product feeds write a price.
    def self.feed(cents, currency)
      "#{format("%.#{format_for(currency)[:precision]}f", BigDecimal(cents) / 100)} #{currency}"
    end
  end
end
