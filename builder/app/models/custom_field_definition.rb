# A field the shop adds to every product (material, care notes): the definition is the shop's,
# each product stores its own value in products.custom_fields.
class CustomFieldDefinition < ApplicationRecord
  acts_as_tenant :shop

  TYPES = %w[ text number boolean ].freeze
  KEY = /\A[a-z][a-z0-9_]{0,40}\z/

  validates :key, presence: true, uniqueness: { scope: :shop_id }, format: { with: KEY }
  validates :label, presence: true, length: { maximum: 80 }
  validates :field_type, inclusion: { in: TYPES }

  normalizes :label, with: ->(label) { label.squish }
  normalizes :key, with: ->(key) { key.to_s.strip }

  before_update :rewrite_product_values
  after_destroy :strip_product_values

  scope :ordered, -> { order(:position, :id) }

  def cast(value)
    case field_type
    when "boolean" then ActiveModel::Type::Boolean.new.cast(value) == true
    when "number"
      return if value.blank?

      Integer(value, exception: false)
    else
      value.to_s.strip.first(500).presence
    end
  end

  private
    # A renamed field keeps its values under the new key. A field whose type changed, or one
    # that was deleted, drops them: a number isn't a sentence.
    def rewrite_product_values
      return unless key_changed? || field_type_changed?

      if field_type_changed?
        strip_key(key_was)
      else
        rename_key(key_was, key)
      end
    end

    def strip_product_values
      strip_key(key)
    end

    def strip_key(old_key)
      Product.find_each do |product|
        next unless product.custom_fields.key?(old_key)

        product.update_columns(custom_fields: product.custom_fields.except(old_key))
      end
    end

    def rename_key(old_key, new_key)
      Product.find_each do |product|
        next unless product.custom_fields.key?(old_key)

        fields = product.custom_fields.except(old_key)
        fields[new_key] = product.custom_fields[old_key]
        product.update_columns(custom_fields: fields)
      end
    end
end
