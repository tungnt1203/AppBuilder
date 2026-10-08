# A change the owner's assistant (or the owner, through it) proposes: new prices, a restock, a
# product paused, its text edited, a sale. Staging one records what would change, before and
# after, and the warnings (a price under cost, a big move); nothing in the shop changes until
# someone applies it, from the assistant or at /admin/agent_changes. Applying writes it in one
# transaction and stamps who did; a discarded or applied change can't be applied again.
class AgentChange < ApplicationRecord
  KINDS = %w[ listing_update price_update inventory_action promotion ].freeze
  STATUSES = %w[ staged applied discarded ].freeze
  LISTING_FIELDS = %w[ title description long_description status ].freeze

  class NotApplicable < StandardError; end

  enum :status, STATUSES.index_by(&:itself), default: "staged"

  validates :kind, inclusion: { in: KINDS }
  validates :summary, presence: true, length: { maximum: 200 }
  validates :created_by, presence: true
  validates :created_by_kind, inclusion: { in: %w[ operator agent ] }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # Records a proposal. Raises NotApplicable (with what the shop can't do) for anything it
  # doesn't manage, and ActiveRecord::RecordNotFound for ids it doesn't know.
  def self.stage!(kind, payload, by:, by_kind: "agent")
    raise NotApplicable, "The shop doesn't manage #{kind.to_s.tr("_", " ")}s" unless KINDS.include?(kind.to_s)

    change = new(kind:, payload: payload.as_json, created_by: by, created_by_kind: by_kind)
    change.send(:"preview_#{kind}")
    change.save!
    change
  end

  def apply!(by:)
    with_lock do
      raise NotApplicable, "This change is #{status}, not staged" unless staged?

      send(:"apply_#{kind}")
      update!(status: "applied", applied_by: by, applied_at: Time.current)
    end
  end

  def discard!(by:, by_kind: "operator")
    with_lock do
      raise NotApplicable, "This change is #{status}, not staged" unless staged?

      update!(status: "discarded", discarded_by: by, discarded_by_kind: by_kind, discarded_at: Time.current)
    end
  end

  def change_id = "CH-#{id}"

  def self.find_by_change_id!(change_id)
    find(change_id.to_s.delete_prefix("CH-"))
  end

  def as_contract_json
    {
      change_id:, kind:, status:, summary:, items:, created_at: created_at.iso8601, created_by:, created_by_kind:,
      applied_at: applied_at&.iso8601, applied_by:, discarded_at: discarded_at&.iso8601, discarded_by:, discarded_by_kind:,
      guardrail_notes:, currency: Store.current.currency, margin_impact: nil,
      margin_before_pct: payload["margin_before_pct"], margin_after_pct: payload["margin_after_pct"]
    }
  end

  private
    def money(cents) = AgentApi::Ids.money(cents)

    def variant!(id)
      AgentApi::Ids.buyable_variant(id) or raise ActiveRecord::RecordNotFound, "No variant #{id} (a product with options needs one of its variants)"
    end

    def variants_of!(id)
      case (record = AgentApi::Ids.find(id))
      when Product then record.variants.to_a
      when Variant then [ record ]
      else raise ActiveRecord::RecordNotFound, "No product or variant #{id}"
      end
    end

    def product!(id)
      record = AgentApi::Ids.find(id) or raise ActiveRecord::RecordNotFound, "No product #{id}"
      raise NotApplicable, "Variants share their product's title, description and status; edit #{AgentApi::Ids.product(record.product)}" if record.is_a?(Variant)
      record
    end

    def label(variant) = [ variant.product.title, variant.title ].compact.join(" – ")

    # -- Prices ------------------------------------------------------------------

    def preview_price_update
      rows = Array(payload["items"]).map do |row|
        variant = variant!(row["listing_id"])
        new_cents = (BigDecimal(row["new_price"].to_s) * 100).round.to_i
        raise NotApplicable, "A price must be above zero" unless new_cents.positive?
        [ variant, new_cents ]
      end
      raise NotApplicable, "Name at least one variant to reprice" if rows.empty?

      self.items = rows.map { |variant, cents| { target: AgentApi::Ids.variant(variant), field: "price", before: money(variant.price_cents), after: money(cents) } }
      self.guardrail_notes = rows.flat_map { |variant, cents| price_notes(variant, cents) }
      if rows.one? && (cost = rows.first.first.cost_cents)
        variant, cents = rows.first
        payload["margin_before_pct"] = margin(variant.price_cents, cost)
        payload["margin_after_pct"] = margin(cents, cost)
      end
      self.summary = rows.one? ? "#{label(rows.first.first)}: #{money(rows.first.first.price_cents)} → #{money(rows.first.last)}" : "New prices for #{rows.size} variants"
    end

    def apply_price_update
      Array(payload["items"]).each do |row|
        variant!(row["listing_id"]).update!(price_cents: (BigDecimal(row["new_price"].to_s) * 100).round.to_i)
      end
    end

    def price_notes(variant, cents)
      notes = []
      notes << "#{label(variant)} would sell below its cost (#{money(variant.cost_cents)})" if variant.cost_cents && cents < variant.cost_cents
      if variant.price_cents.positive?
        move = ((cents - variant.price_cents) * 100.0 / variant.price_cents).round(1)
        notes << "#{label(variant)} moves #{move}%, over the #{AgentApi::Merchant::MAX_PRICE_DELTA_PCT.to_i}% cap" if move.abs > AgentApi::Merchant::MAX_PRICE_DELTA_PCT
      end
      notes << "#{label(variant)} is in a sale now; its price goes back when the sale ends" if variant.promotion_items.joins(:promotion).merge(Promotion.active).exists?
      notes
    end

    def margin(price_cents, cost_cents)
      ((price_cents - cost_cents) * 100.0 / price_cents).round(1) if price_cents.positive?
    end

    # -- Stock and availability ----------------------------------------------------

    def preview_inventory_action
      rows = Array(payload["items"])
      raise NotApplicable, "Name at least one product or variant" if rows.empty?

      self.items = rows.flat_map do |row|
        case row["action"]
        when "restock"
          variant = variant!(row["listing_id"])
          quantity = row["quantity"].to_i
          raise NotApplicable, "A restock needs a quantity above zero" unless quantity.positive?
          [ { target: AgentApi::Ids.variant(variant), field: "stock", before: (variant.track_inventory? ? variant.inventory_quantity : nil), after: (variant.track_inventory? ? variant.inventory_quantity : 0) + quantity } ]
        when "pause", "activate"
          variants_of!(row["listing_id"]).map { |variant| { target: AgentApi::Ids.variant(variant), field: "for_sale", before: variant.available?, after: row["action"] == "activate" } }
        else
          raise NotApplicable, "Unknown action #{row["action"].inspect}: restock, pause or activate"
        end
      end
      self.guardrail_notes = items.select { |item| item[:field] == "stock" && item[:before].nil? }.map { |item| "#{item[:target]} didn't track stock; it will from now on" }
      self.summary = rows.one? ? "#{rows.first["action"].capitalize} #{rows.first["listing_id"]}" : "Stock and availability for #{rows.size} items"
    end

    def apply_inventory_action
      Array(payload["items"]).each do |row|
        case row["action"]
        when "restock"
          variant = variant!(row["listing_id"])
          variant.update!(inventory_quantity: (variant.track_inventory? ? variant.inventory_quantity : 0) + row["quantity"].to_i, track_inventory: true)
        when "pause", "activate"
          variants = variants_of!(row["listing_id"])
          variants.each { |variant| variant.update!(available: row["action"] == "activate") }
          variants.first.product.update!(status: "active") if row["action"] == "activate" && variants.first.product.archived?
        end
      end
    end

    # -- Text and status ------------------------------------------------------------

    def preview_listing_update
      product = product!(payload["listing_id"])
      fields = payload.fetch("fields", {}).stringify_keys
      unknown = fields.keys - LISTING_FIELDS
      raise NotApplicable, "The shop doesn't store #{unknown.to_sentence}; it has #{LISTING_FIELDS.join(", ")}" if unknown.any?
      raise NotApplicable, "Status is active, draft or paused" if fields["status"] && !fields["status"].in?(%w[ active draft paused ])

      self.items = fields.map { |field, value| { target: AgentApi::Ids.product(product), field:, before: current_field(product, field), after: value } }
      self.summary = "Edit #{product.title}: #{fields.keys.to_sentence}"
    end

    def apply_listing_update
      product = product!(payload["listing_id"])
      fields = payload.fetch("fields", {}).stringify_keys
      attributes = {}
      attributes[:title] = fields["title"] if fields.key?("title")
      attributes[:description] = fields["long_description"] || fields["description"] if fields.key?("description") || fields.key?("long_description")
      attributes[:status] = { "paused" => "archived" }.fetch(fields["status"], fields["status"]) if fields.key?("status")
      product.update!(attributes)
    end

    def current_field(product, field)
      case field
      when "title" then product.title
      when "description", "long_description" then product.description
      when "status" then { "archived" => "paused" }.fetch(product.status, product.status)
      end
    end

    # -- Sales ------------------------------------------------------------------------

    def preview_promotion
      promotion = build_promotion
      raise NotApplicable, promotion.errors.full_messages.to_sentence unless promotion.valid?
      raise NotApplicable, "A sale can take at most #{AgentApi::Merchant::MAX_PROMOTION_DISCOUNT_PCT.to_i}% off" if promotion.percent_off > AgentApi::Merchant::MAX_PROMOTION_DISCOUNT_PCT

      variants = Variant.where(id: promotion.variant_ids).includes(:product)
      self.items = variants.map do |variant|
        { target: AgentApi::Ids.variant(variant), field: "price", before: money(variant.price_cents), after: money(promotion.sale_price_cents(variant.price_cents)) }
      end
      self.guardrail_notes = variants.filter_map do |variant|
        "#{label(variant)} would sell below its cost (#{money(variant.cost_cents)})" if variant.cost_cents && promotion.sale_price_cents(variant.price_cents) < variant.cost_cents
      end
      self.summary = "#{promotion.name}: #{promotion.percent_off}% off #{variants.size} variants, #{promotion.starts_at.to_date} to #{promotion.ends_at.to_date}"
      self.summary = summary.truncate(200)
    end

    def apply_promotion
      promotion = build_promotion
      promotion.save!
      promotion.start!
    end

    def build_promotion
      draft = payload
      ids = Array(draft["listing_ids"]).flat_map { |id| variants_of!(id).map(&:id) }
      Promotion.new(name: draft["name"], percent_off: draft["discount_pct"].to_f.round, variant_ids: ids,
        starts_at: parse_day(draft["starts"])&.beginning_of_day, ends_at: parse_day(draft["ends"])&.end_of_day)
    end

    def parse_day(text)
      Time.zone.parse(text.to_s)
    rescue ArgumentError
      nil
    end

  Shop.extend_model(self)
end
