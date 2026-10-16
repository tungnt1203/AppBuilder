# What the buyer fills in at checkout, kept for the form and sent to the Platform as it is. The
# Platform says what's wrong with it (problems), which shows as the form's errors.
class CheckoutForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  FIELDS = %i[ email phone shipping_name shipping_address1 shipping_address2 shipping_city shipping_region
    shipping_postal_code shipping_country note payment_method ].freeze
  FIELDS.each { |field| attribute field, :string }

  # The Platform's { "email" => "is invalid" } as this form's errors; a problem with no field goes on top.
  def add_problems(problems, message = nil)
    problems.to_h.each { |field, problem| errors.add(FIELDS.include?(field.to_sym) ? field.to_sym : :base, problem) }
    errors.add(:base, message) if message && problems.blank?
  end

  def to_api = attributes.symbolize_keys.compact_blank
end
