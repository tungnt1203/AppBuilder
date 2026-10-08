module MoneyHelper
  # money(1999) => "$19.99" in the shop's currency; money(1999, "EUR") => "€19.99".
  def money(cents, currency = Store.current.currency)
    return if cents.nil?

    format = Store::CURRENCIES.fetch(currency) { Store::CURRENCIES["USD"] }
    number_to_currency(BigDecimal(cents) / 100, unit: format[:unit], precision: format[:precision],
      format: format.fetch(:format, "%u%n"), negative_format: "-#{format.fetch(:format, "%u%n")}")
  end

  # "$12.00", or "$12.00 – $18.00" when the variants differ.
  def price_range(product, currency = Store.current.currency)
    low, high = product.price_range
    return unless low

    low == high ? money(low, currency) : "#{money(low, currency)} – #{money(high, currency)}"
  end
end
