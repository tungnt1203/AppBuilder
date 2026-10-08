# Something the shop sells. Its variants are the combinations of up to three options
# (Color × Size), each with its own price; a product without options has one variant.
class Product < ApplicationRecord
  include Sluggable, MoneyAttributes

  OPTION_SLOTS = [ 1, 2, 3 ].freeze

  has_many :variants, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :product
  has_many :collection_products, dependent: :destroy
  has_many :collections, through: :collection_products
  has_many_attached :images do |image|
    image.variant :thumb, resize_to_fill: [ 160, 160 ], format: :webp
    image.variant :card, resize_to_fill: [ 640, 800 ], format: :webp
    image.variant :large, resize_to_limit: [ 1400, 1400 ], format: :webp
  end

  accepts_nested_attributes_for :variants

  enum :status, %w[ draft active archived ].index_by(&:itself), default: "draft"

  # The starting price for new variants, from the product form.
  attribute :base_price_cents, :integer
  money_attribute :base_price

  validates :title, presence: true, length: { maximum: 200 }
  validates :base_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :options_are_consistent
  validate :images_are_images

  normalizes :title, with: ->(title) { title.squish }
  OPTION_SLOTS.each do |slot|
    normalizes :"option#{slot}_name", with: ->(name) { name.squish.presence }
    normalizes :"option#{slot}_values", with: ->(values) { Array(values).map { |value| value.to_s.squish }.compact_blank.uniq }
  end

  before_save :stamp_published_at
  after_save :sync_variants

  scope :visible, -> { active }
  scope :ordered, -> { order(created_at: :desc, id: :desc) }
  scope :newest_first, -> { order(published_at: :desc, id: :desc) }
  scope :search, ->(query) { where("products.title LIKE ?", "%#{sanitize_sql_like(query.to_s.strip)}%") if query.present? }

  # Option names in use, in slot order: ["Color", "Size"].
  def option_names
    OPTION_SLOTS.filter_map { |slot| public_send("option#{slot}_name") }
  end

  def options
    OPTION_SLOTS.filter_map do |slot|
      name = public_send("option#{slot}_name")
      [ slot, name, public_send("option#{slot}_values") ] if name
    end
  end

  # "S, M, L" in the product form for each slot's values.
  OPTION_SLOTS.each do |slot|
    define_method("option#{slot}_values_text") { public_send("option#{slot}_values").join(", ") }
    define_method("option#{slot}_values_text=") { |text| public_send("option#{slot}_values=", text.to_s.split(",")) }
  end

  def has_options?
    option_names.any?
  end

  def available_variants
    variants.select(&:sellable?)
  end

  def available?
    active? && variants.any?(&:sellable?)
  end

  def price_range
    prices = (available_variants.presence || variants).map(&:price_cents)
    prices.minmax if prices.any?
  end

  def cover_image
    images.first
  end

  def variant_for(selected)
    variants.find { |variant| variant.matches?(selected) }
  end

  private
    def stamp_published_at
      self.published_at ||= Time.current if active?
    end

    def options_are_consistent
      OPTION_SLOTS.each do |slot|
        name, values = public_send("option#{slot}_name"), public_send("option#{slot}_values")
        errors.add(:"option#{slot}_values", :blank) if name && values.empty?
        errors.add(:"option#{slot}_name", :blank) if name.nil? && values.any?
      end
      errors.add(:base, :options_in_order) if option_names.size != OPTION_SLOTS.take_while { |slot| public_send("option#{slot}_name") }.size
      errors.add(:base, :too_many_variants) if variant_combinations.size > 100
    end

    def images_are_images
      images.each do |image|
        next if image.blob.content_type.to_s.start_with?("image/")
        errors.add(:images, :not_an_image, name: image.blob.filename.to_s)
      end
    end

    # Every combination of the option values: [["Black", "S"], ["Black", "M"], …], or [[]] without options.
    def variant_combinations
      lists = options.map { |_slot, _name, values| values }
      lists.empty? ? [ [] ] : lists.first.product(*lists.drop(1))
    end

    # Adds a variant for each new combination (at the base price, or the first variant's) and
    # removes the ones whose combination is gone. Prices and SKUs of the others stay as they are.
    def sync_variants
      combinations = variant_combinations
      existing = variants.reload.index_by(&:option_values)
      price = base_price_cents || existing.values.first&.price_cents || 0

      (existing.keys - combinations).each { |values| existing[values].destroy! }
      combinations.each_with_index do |values, position|
        variant = existing[values] || variants.build(option1: values[0], option2: values[1], option3: values[2], price_cents: price)
        variant.position = position
        variant.save! if variant.changed?
      end
      variants.reset
    end

  Shop.extend_model(self)
end
