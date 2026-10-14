# A buyer's review of a product they bought: stars (1 to 5), what they thought, and the name
# shown with it ("Robin B."). Written from the order's review page (reached by the order's token,
# linked from the email Order::RequestReviewsJob sends), one per product and order, so every
# review is from a real buyer.
#
# Reviews show as soon as they're written. Staff can hide one that's spam, offensive or not about
# the product, but never for being negative: hiding bad reviews misleads buyers and breaks the
# FTC's rules and the ad networks'.
class ProductReview < ApplicationRecord
  STATUSES = %w[ published hidden ].freeze

  belongs_to :product
  belongs_to :order

  enum :status, STATUSES.index_by(&:itself), default: "published"

  validates :rating, numericality: { only_integer: true, in: 1..5 }
  validates :body, length: { maximum: 2000 }
  validates :author_name, presence: true, length: { maximum: 60 }
  validates :product_id, uniqueness: { scope: :order_id }
  validate :product_was_bought

  normalizes :body, :author_name, with: ->(value) { value.strip.squeeze(" ").presence }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # "Robin Buyer" → "Robin B.", the name shown unless the buyer writes another.
  def self.default_author_name(full_name)
    first, *rest = full_name.to_s.split
    [ first&.upcase_first, rest.last&.first&.then { "#{_1.upcase}." } ].compact.join(" ").presence
  end

  def hide!
    update!(status: "hidden")
  end

  def publish!
    update!(status: "published")
  end

  private
    def product_was_bought
      errors.add(:product, :not_bought) if order && product && order.line_items.none? { |item| item.variant&.product_id == product_id }
    end

  Shop.extend_model(self)
end
