# A list of links the storefront shows (header, footer). Each item is a label and a path on the
# storefront (/pages/about) or a full https address.
class Menu < ApplicationRecord
  acts_as_tenant :shop

  KEY = /\A[a-z][a-z0-9_]{0,40}\z/

  validates :key, presence: true, uniqueness: { scope: :shop_id }, format: { with: KEY }
  validates :title, presence: true, length: { maximum: 80 }
  validate :items_are_links

  normalizes :title, with: ->(title) { title.squish }
  normalizes :key, with: ->(key) { key.to_s.strip }

  before_validation :clean_items

  def to_param
    key_was.presence || key
  end

  private
    def clean_items
      self.items = Array(items).filter_map { |row|
        row = row.stringify_keys
        label = row["label"].to_s.squish
        url = row["url"].to_s.strip
        next if label.blank? && url.blank?

        { "label" => label.first(80), "url" => url }
      }.first(30)
    end

    def items_are_links
      items.each do |item|
        errors.add(:base, :blank_item) if item["label"].blank? || item["url"].blank?
        errors.add(:base, :bad_url, url: item["url"]) unless safe_url?(item["url"])
      end
      errors.add(:base, :empty) if items.empty?
    end

    def safe_url?(url)
      url.start_with?("/") && !url.start_with?("//") || url.match?(/\Ahttps?:\/\//)
    end
end
