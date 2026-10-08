# A sale: the prices of some variants lowered by percent_off from starts_at to ends_at (or
# raised, with a negative percent_off: a peak-time price). Promotion::SyncJob starts and ends
# sales on time. Starting one keeps each variant's price, sets the sale price and shows the old
# price as the compare-at price; ending it puts both back.
class Promotion < ApplicationRecord
  STATUSES = %w[ scheduled active ended cancelled ].freeze

  has_many :items, class_name: "PromotionItem", dependent: :destroy
  has_many :variants, through: :items

  enum :status, STATUSES.index_by(&:itself), default: "scheduled"

  validates :name, presence: true, length: { maximum: 80 }
  validates :percent_off, numericality: { only_integer: true, in: -90..90, other_than: 0 }
  validates :starts_at, :ends_at, presence: true
  validate :ends_after_start
  validate :has_items
  validate :no_overlapping_sale

  scope :ordered, -> { order(starts_at: :desc) }
  scope :due_to_start, ->(now = Time.current) { scheduled.where(starts_at: ..now).where("promotions.ends_at > ?", now) }
  scope :due_to_end, ->(now = Time.current) { where(status: %w[ scheduled active ]).where(ends_at: ..now) }
  scope :current_or_upcoming, -> { where(status: %w[ scheduled active ]) }

  # Every variant of these products, or these variants.
  def variant_ids=(ids)
    super(Array(ids).compact_blank)
  end

  def sale_price_cents(original_cents)
    (original_cents * (100 - percent_off) / 100.0).round
  end

  def start!(now = Time.current)
    with_lock do
      return false unless scheduled? && starts_at <= now && ends_at > now

      items.includes(:variant).each do |item|
        variant = item.variant
        item.update!(original_price_cents: variant.price_cents, original_compare_at_price_cents: variant.compare_at_price_cents)
        compare_at = percent_off.positive? ? [ variant.compare_at_price_cents.to_i, variant.price_cents ].max : variant.compare_at_price_cents
        variant.update!(price_cents: sale_price_cents(variant.price_cents), compare_at_price_cents: compare_at)
      end
      active!
    end
  end

  # Puts the prices back, except on a variant whose price staff changed during the sale.
  def finish!(status = "ended")
    with_lock do
      return false unless scheduled? || active?

      if active?
        items.includes(:variant).each do |item|
          variant = item.variant
          next unless item.original_price_cents && variant.price_cents == sale_price_cents(item.original_price_cents)

          variant.update!(price_cents: item.original_price_cents, compare_at_price_cents: item.original_compare_at_price_cents)
        end
      end
      update!(status:)
    end
  end

  def cancel!
    finish!("cancelled")
  end

  private
    def ends_after_start
      errors.add(:ends_at, :before_start) if starts_at && ends_at && ends_at <= starts_at
    end

    def has_items
      errors.add(:base, :no_items) if items.empty? && variant_ids.empty?
    end

    def no_overlapping_sale
      return unless starts_at && ends_at

      ids = items.map(&:variant_id).presence || variant_ids
      clash = PromotionItem.joins(:promotion).merge(Promotion.current_or_upcoming).where(variant_id: ids)
        .where.not(promotion_id: id).where("promotions.starts_at < ? AND promotions.ends_at > ?", ends_at, starts_at).first
      errors.add(:base, :overlaps, product: clash.variant.product.title) if clash
    end

  Shop.extend_model(self)
end
