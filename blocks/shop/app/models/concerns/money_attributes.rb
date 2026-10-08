# Money is stored as integer cents (price_cents) and edited as a decimal (price):
#   money_attribute :price, :compare_at_price
# gives price / price= that read and write price_cents, so forms take "19.99".
module MoneyAttributes
  extend ActiveSupport::Concern

  class_methods do
    def money_attribute(*names)
      names.each do |name|
        define_method(name) do
          cents = public_send("#{name}_cents")
          cents && BigDecimal(cents) / 100
        end

        # What forms show: "24.00", not "24.0".
        define_method("#{name}_before_type_cast") do
          cents = public_send("#{name}_cents")
          cents && format("%.2f", BigDecimal(cents) / 100)
        end

        define_method("#{name}=") do |value|
          amount = value.is_a?(String) ? value.strip.delete(",") : value
          cents = amount.blank? ? nil : (BigDecimal(amount.to_s) * 100).round.to_i
          public_send("#{name}_cents=", cents)
        rescue ArgumentError
          public_send("#{name}_cents=", nil)
          @invalid_money = (@invalid_money || []) | [ name ]
        end
      end

      validate do
        Array(@invalid_money).each { |name| errors.add(name, :not_a_number) }
      end
    end
  end
end
