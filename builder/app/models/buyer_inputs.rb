# Text the buyer types on a product ("Name on the shirt", at most 20 characters). The product
# stores the definitions; the cart line stores what they typed, and the order carries it to Printify.
class BuyerInputs
  KEY = /\A[a-z][a-z0-9_]{0,40}\z/
  MAX_FIELDS = 10
  MAX_LENGTH = 80

  def self.definitions(rows)
    used = []
    Array(rows).filter_map { |row|
      row = row.stringify_keys
      label = row["label"].to_s.squish
      next if label.blank?

      key = row["key"].to_s.parameterize(separator: "_").presence || label.parameterize(separator: "_")
      next unless key.match?(KEY) && used.exclude?(key)

      used << key
      length = row["max_length"].to_i
      length = 40 unless (1..MAX_LENGTH).cover?(length)
      { "key" => key, "label" => label.first(80), "required" => ActiveModel::Type::Boolean.new.cast(row["required"]) == true, "max_length" => length }
    }.first(MAX_FIELDS)
  end

  # [properties, nil] when what the buyer typed fits, or [nil, { "print_name" => "can't be blank" }].
  def self.accept(definitions, raw)
    raw = case raw
    when ActionController::Parameters then raw.to_unsafe_h
    when Hash then raw
    else {}
    end.stringify_keys
    errors = {}
    properties = {}
    Array(definitions).each do |field|
      value = raw[field["key"]].to_s.strip
      if value.blank?
        errors[field["key"]] = "can't be blank" if field["required"]
      elsif value.length > field["max_length"]
        errors[field["key"]] = "is too long (maximum is #{field["max_length"]} characters)"
      else
        properties[field["key"]] = value
      end
    end
    errors.empty? ? [ properties, nil ] : [ nil, errors ]
  end
end
