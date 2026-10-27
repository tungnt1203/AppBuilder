# Something the shop sells. Its variants are the combinations of up to three options
# (Color × Size), each with its own price; a product without options has one variant.
class Product < ApplicationRecord
  acts_as_tenant :shop

  include Sluggable, MoneyAttributes

  OPTION_SLOTS = [ 1, 2, 3 ].freeze
  # A Printify tee comes in dozens of colors and several sizes.
  MAX_VARIANTS = 400

  has_many :variants, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :product
  has_many :collection_products, dependent: :destroy
  has_many :collections, through: :collection_products
  has_many :product_reviews, dependent: :destroy
  # The sides a personalized product prints what buyers add on (Printify's placeholder positions).
  PRINT_POSITIONS = %w[ front back ].freeze

  has_many_attached :images do |image|
    image.variant :thumb, resize_to_fill: [ 160, 160 ], format: :webp
    image.variant :card, resize_to_fill: [ 640, 800 ], format: :webp
    image.variant :large, resize_to_limit: [ 1400, 1400 ], format: :webp
  end
  # Pictures the buyer picks from to have printed (a "choice" field of buyer_inputs: their dog's
  # breed), kept apart from the product's photos. A picture's name is its file's ("Golden retriever.png").
  has_many_attached :artwork do |art|
    art.variant :thumb, resize_to_limit: [ 160, 160 ], format: :webp
    art.variant :large, resize_to_limit: [ 1000, 1000 ], format: :webp
  end

  accepts_nested_attributes_for :variants

  enum :status, %w[ draft active archived ].index_by(&:itself), default: "draft"

  # The starting price for new variants, from the product form.
  attribute :base_price_cents, :integer
  money_attribute :base_price

  validates :title, presence: true, length: { maximum: 200 }
  validates :base_price_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :size_guide, length: { maximum: 10_000 }
  validate :options_are_consistent
  validate :images_are_images

  normalizes :title, with: ->(title) { title.squish }
  OPTION_SLOTS.each do |slot|
    normalizes :"option#{slot}_name", with: ->(name) { name.squish.presence }
    normalizes :"option#{slot}_values", with: ->(values) { Array(values).map { |value| value.to_s.squish }.compact_blank.uniq }
  end

  before_validation :clean_buyer_inputs, :clean_print_areas
  before_validation :coerce_custom_fields
  before_save :stamp_published_at
  after_save :sync_variants
  after_commit :find_print_pixels, if: -> { saved_change_to_print_areas? && print_areas.values.any? { |area| area["pixels"].blank? } && printify_product_id }

  scope :visible, -> { active }
  scope :ordered, -> { order(created_at: :desc, id: :desc) }
  scope :newest_first, -> { order(published_at: :desc, id: :desc) }
  scope :search, ->(query) { where("products.title ILIKE ?", "%#{sanitize_sql_like(query.to_s.strip)}%") if query.present? }

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

  # The pictures buyers pick from in its choice fields, by id: its own artwork and the pictures
  # of the shop's sets it offers (ClipartSet).
  def choice_pictures
    set_ids = buyer_inputs.to_a.filter_map { |field| field["set"] }
    sets = set_ids.any? ? clipart_sets(set_ids).includes(pictures_attachments: :blob).flat_map { |set| set.pictures.attachments } : []
    (artwork.attachments.to_a + sets).index_by(&:id)
  end

  # The shop's sets among these, wherever it's asked from (a job, the storefront's API).
  def clipart_sets(ids)
    ActsAsTenant.without_tenant { ClipartSet.where(shop_id:, id: ids) }
  end

  # Brings its choice fields up to date with the sets they offer, as they change or go.
  def refresh_clipart
    fields = with_choice_options(buyer_inputs.to_a)
    update_column(:buyer_inputs, fields) if fields != buyer_inputs
  end

  def available_variants
    variants.select(&:sellable?)
  end

  # What to fix before a product goes on sale: :no_photos, :price_not_above_cost (a variant on
  # sale for no more than it costs), :no_size_guide (sizes without a chart). Empty when ready.
  def launch_problems
    problems = []
    problems << :no_photos unless images.attached?
    problems << :price_not_above_cost if variants.any? { |variant| variant.available? && variant.cost_cents && variant.price_cents <= variant.cost_cents }
    problems << :no_size_guide if size_option_name && size_guide.blank?
    problems << :no_print_area if prints_personalized? && (print_areas.empty? || (print_sides - print_areas.keys).any?)
    problems
  end

  def available?
    active? && variants.any?(&:sellable?)
  end

  # Printify prints it with what the buyer adds (a name, a photo): the print areas tell where.
  def prints_personalized? = printify_product_id.present? && buyer_inputs.any?

  # The sides its fields print on ("front", "back"), each needing its print area.
  def print_sides = buyer_inputs.filter_map { |field| BuyerInputs.side(field) if field["preview"] }.uniq

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

  # Other products to show under this one ("You may also like"): from its collections first,
  # then the newest.
  # Its published reviews' average and count, nil before the first: { average: 4.6, count: 12 }.
  def rating_summary
    count, average = product_reviews.published.pick(Arel.sql("COUNT(*)"), Arel.sql("AVG(rating)"))
    { average: average.to_f.round(1), count: } if count.to_i.positive?
  end

  def related(limit: 4)
    others = Product.visible.where.not(id:).with_attached_images.includes(:variants)
    picked = others.joins(:collection_products).where(collection_products: { collection_id: collection_ids }).distinct.newest_first.limit(limit).to_a
    picked + others.where.not(id: picked.map(&:id)).newest_first.limit(limit - picked.size).to_a
  end

  # The photo that shows a variant: the one the owner set for one of its option values
  # (option_images, {"White" => attachment id}), else one whose file name has its color in it
  # ("tee-white.jpg", as mockup generators name them), else the cover.
  def image_for(variant)
    return cover_image unless variant

    photos = images.select(&:representable?)
    chosen = variant.option_values.lazy.filter_map { |value| photos.find { |photo| photo.id == option_images[value].to_i } }.first
    chosen ||= color_value(variant)&.then { |color| photos.find { |photo| photo.filename.base.parameterize.split("-").each_cons(color.size).include?(color) } }
    chosen || cover_image
  end

  # The option value a photo shows ("White"), for the product form.
  def photo_option(image)
    option_images.key(image.id)
  end

  # From the product form: {attachment id => "White"}, one value per photo.
  def photo_options=(map)
    self.option_images = map.to_h.each_with_object({}) { |(id, value), images| images[value.to_s] = id.to_i if value.present? }
  end

  # The size option's name when the product has one ("Size"), where a size guide goes.
  def size_option_name
    option_names.find { |name| name.match?(/\bsize\b/i) }
  end

  # What the buyer typed, checked against this product's buyer inputs.
  # [properties, nil] or [nil, { "print_name" => "can't be blank" }].
  def buyer_properties(raw)
    BuyerInputs.accept(buyer_inputs, raw)
  end

  def custom_field_entries
    CustomFieldDefinition.ordered.filter_map do |definition|
      next unless custom_fields.key?(definition.key)

      { key: definition.key, label: definition.label, type: definition.field_type, value: custom_fields[definition.key] }
    end
  end

  # How many pixels a field's box prints at, [width, height] (Printify's 300 dots an inch), or nil
  # until the size of its side's print area is known.
  def print_pixels(field)
    area, box = print_areas[BuyerInputs.side(field)], field["preview"]
    return unless area && area["pixels"] && box

    [ (box["w"] / area["w"] * area["pixels"][0]).round, (box["h"] / area["h"] * area["pixels"][1]).round ]
  end

  private
    # The variant's color as file-name words ("Forest Green" => ["forest", "green"]), when the
    # product has a color option.
    def color_value(variant)
      slot = OPTION_SLOTS.find { |slot| public_send("option#{slot}_name").to_s.match?(/\bcolou?r\b/i) }
      variant.public_send("option#{slot}").to_s.parameterize.split("-").presence if slot
    end

    def stamp_published_at
      self.published_at ||= Time.current if active?
    end

    # Where each side's print area sits on a photo of the product (BuyerInputs.preview's box, drawn
    # on a photo of that side) and, once Printify said (Product::PrintPixelsJob), its size in pixels:
    # { "front" => { x, y, w, h, pixels } }, a side only once the owner draws it. Moving a box keeps
    # its size.
    def clean_print_areas
      given = print_areas.to_h.stringify_keys
      self.print_areas = PRINT_POSITIONS.each_with_object({}) do |side, areas|
        raw = given[side].to_h.stringify_keys
        box = BuyerInputs.preview(raw, kind: "photo") or next
        pixels = Array(raw["pixels"].presence || print_areas_was.to_h.dig(side, "pixels")).map(&:to_i)
        areas[side] = box.slice("x", "y", "w", "h").merge("pixels" => (pixels if pixels.size == 2 && pixels.all?(&:positive?))).compact
      end
    end

    def find_print_pixels
      Product::PrintPixelsJob.perform_later(self)
    end

    def clean_buyer_inputs
      self.buyer_inputs = with_choice_options(BuyerInputs.definitions(buyer_inputs))
    end

    # A choice field offers the pictures of the shop's set it names, all of them in the set's
    # order, or else only the product's own artwork it lists.
    def with_choice_options(fields)
      artwork_ids = artwork.attachments.map(&:id)
      sets = clipart_sets(fields.filter_map { |field| field["set"] }).includes(:pictures_attachments).index_by(&:id)
      fields.map do |field|
        next field unless field["kind"] == "choice"

        if field["set"] && (set = sets[field["set"]])
          field.merge("options" => set.pictures.attachments.sort_by(&:id).map(&:id))
        else
          field.except("set").merge("options" => field["options"].to_a & artwork_ids)
        end
      end
    end

    def coerce_custom_fields
      definitions = CustomFieldDefinition.all.index_by(&:key)
      coerced = {}
      custom_fields.each do |key, value|
        definition = definitions[key] or next
        cast = definition.cast(value)
        if definition.field_type == "number" && value.present? && !cast.is_a?(Integer)
          errors.add(:base, :custom_field_number, label: definition.label)
        elsif definition.field_type == "text" && value.to_s.length > 500
          errors.add(:base, :custom_field_long, label: definition.label)
        end
        coerced[key] = cast unless cast.nil?
      end
      self.custom_fields = coerced
    end

    def options_are_consistent
      OPTION_SLOTS.each do |slot|
        name, values = public_send("option#{slot}_name"), public_send("option#{slot}_values")
        errors.add(:"option#{slot}_values", :blank) if name && values.empty?
        errors.add(:"option#{slot}_name", :blank) if name.nil? && values.any?
      end
      errors.add(:base, :options_in_order) if option_names.size != OPTION_SLOTS.take_while { |slot| public_send("option#{slot}_name") }.size
      errors.add(:base, :too_many_variants, count: MAX_VARIANTS) if variant_combinations.size > MAX_VARIANTS
    end

    def images_are_images
      (images.to_a + artwork.to_a).each do |image|
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
end
