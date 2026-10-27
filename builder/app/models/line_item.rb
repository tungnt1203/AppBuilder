# One line of an order, with the product's title, option values and price copied in at checkout.
class LineItem < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :order
  belongs_to :variant, optional: true
  # A personalized item's print files, a side each, as they went to Printify (Personalization::PrintifyLine).
  has_many_attached :print_files

  validates :product_title, presence: true
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :quantity, numericality: { greater_than: 0, only_integer: true }

  def total_cents
    unit_price_cents * quantity
  end

  def product
    variant&.product
  end

  # What the buyer added, as "Label: value" lines ("Name on the shirt: Ada", "Your photo: Added"),
  # using the product's labels while it still has them.
  def property_lines
    property_entries.map { |entry| "#{entry[:label]}: #{entry[:value]}" }
  end

  # What the buyer added as BuyerInputs.entries: [{ key, label, value, kind, raw }].
  def property_entries
    return [] if properties.blank?

    BuyerInputs.entries(product&.buyer_inputs, properties, artwork: product ? product.choice_pictures : {})
  end

  # The photos the buyer added, to print: [{ label, upload, crop: [zoom, x, y], sharp: whether it's
  # big enough to print sharp }].
  def buyer_photos
    fields = product&.buyer_inputs.to_a.select { |field| field["kind"] == "photo" && properties.to_h[field["key"]].present? }
    uploads = BuyerUpload.where(token: fields.map { |field| properties[field["key"]] }).index_by(&:token)
    fields.filter_map do |field|
      upload = uploads[properties[field["key"]]] or next
      crop = BuyerInputs.crop(properties["#{field["key"]}_crop"])
      { label: field["label"], upload:, crop:, sharp: upload.sharp_for?(product.print_pixels(field), crop[0]) }
    end
  end
end
