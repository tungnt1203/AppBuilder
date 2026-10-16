# A form the storefront posts to (contact, a wholesale enquiry). The theme can declare its fields
# on publish (declare!); the owner can declare them here too. Submissions are kept and emailed.
class Form < ApplicationRecord
  acts_as_tenant :shop

  FIELD_TYPES = %w[ text email textarea boolean ].freeze
  KEY = /\A[a-z][a-z0-9_]{0,40}\z/

  has_many :submissions, class_name: "FormSubmission", dependent: :destroy

  validates :key, presence: true, uniqueness: { scope: :shop_id }, format: { with: KEY }
  validates :title, presence: true, length: { maximum: 80 }
  validate :has_fields

  normalizes :title, with: ->(title) { title.squish }
  normalizes :key, with: ->(key) { key.to_s.strip }

  before_validation :clean_fields

  def self.declare!(key, title:, fields:)
    record = find_or_initialize_by(key: key.to_s)
    record.title = title
    record.fields = fields
    record.save!
    record
  end

  def to_param
    key_was.presence || key
  end

  def field(key)
    fields.find { |field| field["key"] == key }
  end

  private
    def clean_fields
      used = []
      self.fields = Array(fields).filter_map { |row|
        row = row.stringify_keys
        label = row["label"].to_s.squish
        key = row["key"].to_s.parameterize(separator: "_").presence || label.parameterize(separator: "_")
        type = row["type"].presence || row["field_type"].presence || "text"
        next if label.blank? || key.blank? || !key.match?(KEY) || FIELD_TYPES.exclude?(type) || used.include?(key)

        used << key
        { "key" => key, "label" => label.first(80), "type" => type, "required" => ActiveModel::Type::Boolean.new.cast(row["required"]) == true }
      }.first(20)
    end

    def has_fields
      errors.add(:base, :empty) if fields.blank?
    end
end
