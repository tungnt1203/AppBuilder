# One line of an order, with the product's title, option values and price copied in at checkout.
class LineItem < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :order
  belongs_to :variant, optional: true

  validates :product_title, presence: true
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :quantity, numericality: { greater_than: 0, only_integer: true }

  def total_cents
    unit_price_cents * quantity
  end

  def product
    variant&.product
  end

  # "Name on the shirt: Ada", using the product's labels while it still has them.
  # What the buyer added, as "Label: value" lines (emails, the admin): a photo as "Photo added",
  # without its framing; a picture by its name.
  def property_lines
    return [] if properties.blank?

    fields = product&.buyer_inputs.to_a
    photos = fields.select { |field| field["kind"] == "photo" }.map { |field| field["key"] }
    labels = fields.each_with_object({}) do |field, all|
      all[field["key"]] = field["label"]
      all["#{field["key"]}_font"] = "#{field["label"]} font"
      all["#{field["key"]}_color"] = "#{field["label"]} color"
    end
    choices = fields.select { |field| field["kind"] == "choice" }.map { |field| field["key"] }
    artwork = choices.any? ? product.artwork.attachments.index_by(&:id) : {}
    properties.filter_map do |key, value|
      next if photos.any? { |photo| key == "#{photo}_crop" }

      value = "Photo added" if photos.include?(key)
      value = artwork[value.to_i]&.filename&.base&.humanize || value if choices.include?(key)
      "#{labels[key] || key}: #{value}"
    end
  end

  # The photos the buyer added, to print: [{ label, upload, crop: [zoom, x, y] }].
  def buyer_photos
    fields = product&.buyer_inputs.to_a.select { |field| field["kind"] == "photo" && properties.to_h[field["key"]].present? }
    uploads = BuyerUpload.where(token: fields.map { |field| properties[field["key"]] }).index_by(&:token)
    fields.filter_map do |field|
      upload = uploads[properties[field["key"]]] or next
      { label: field["label"], upload:, crop: BuyerInputs.crop(properties["#{field["key"]}_crop"]) }
    end
  end
end
