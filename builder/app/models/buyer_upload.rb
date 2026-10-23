# A photo a buyer adds to a personalized product (BuyerInputs, a "photo" field), sent by the
# storefront before they buy. The cart line, then the order, keep its token; staff (and later the
# print file) take the photo from here. Its size is kept to warn about photos too small to print well.
class BuyerUpload < ApplicationRecord
  TYPES = %w[ image/jpeg image/png image/webp ].freeze
  MAX_SIZE = 20.megabytes

  acts_as_tenant :shop

  has_one_attached :photo do |photo|
    photo.variant :thumb, resize_to_fill: [ 160, 160 ], format: :webp
    photo.variant :large, resize_to_limit: [ 1400, 1400 ], format: :webp
  end

  validates :photo, presence: true
  validate :photo_is_an_image

  before_create { self.token = "upl_#{SecureRandom.base58(24)}" }

  # Photos added over 30 days ago that no cart line or order line has (the buyer didn't buy, and the
  # cart was cleared): Cart::CleanupJob removes them.
  scope :unused, -> { where(created_at: ...30.days.ago).where.not(token: tokens_in_use) }

  def self.tokens_in_use
    [ CartItem, LineItem ].flat_map { |lines| lines.where("properties::text LIKE '%upl\\_%'").pluck(:properties) }
      .flat_map { |properties| properties.to_h.values }.grep(/\Aupl_/).uniq
  end

  # Takes an uploaded file: keeps it and its size, or returns the upload with its errors.
  def self.take(file)
    upload = new
    upload.photo.attach(file) if file.respond_to?(:original_filename)
    return upload unless upload.save

    blob = upload.photo.blob.tap(&:analyze)
    upload.update!(width: blob.metadata["width"], height: blob.metadata["height"])
    upload
  end

  # Printify prints at 300 dots an inch; half of that still looks sharp on a shirt or a mug.
  SHARP = 0.5

  # Whether the photo, filling a box printed at pixels ([width, height], Product#print_pixels) and
  # zoomed in as the buyer framed it, has enough of its own pixels to print sharp. True when the
  # box's size isn't known.
  def sharp_for?(pixels, zoom = 1)
    return true unless pixels && width.to_i.positive? && height.to_i.positive?

    shown = [ width, height * pixels[0].to_f / pixels[1] ].min / zoom
    shown >= pixels[0] * SHARP
  end

  private
    def photo_is_an_image
      return unless photo.attached?

      errors.add(:photo, "must be a JPEG, PNG or WebP photo") unless TYPES.include?(photo.blob.content_type)
      errors.add(:photo, "is too big (20 MB at most)") if photo.blob.byte_size > MAX_SIZE
    end
end
