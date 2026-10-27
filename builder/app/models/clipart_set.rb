# A set of pictures buyers pick from to have printed (the twelve zodiac signs, dog breeds), kept
# once for the shop. A product's choice field can offer a set (its "set") instead of pictures of
# its own: the field's options follow the set, so a picture added to it or taken out shows on every
# product that offers it. A picture's name is its file's ("Golden retriever.png"), and can be changed.
class ClipartSet < ApplicationRecord
  acts_as_tenant :shop

  MAX_PICTURES = BuyerInputs::MAX_OPTIONS
  # What prints well and makes thumbnails: a transparent PNG is best.
  TYPES = %w[ image/png image/webp image/jpeg ].freeze

  has_many_attached :pictures do |picture|
    picture.variant :thumb, resize_to_limit: [ 160, 160 ], format: :webp
    picture.variant :large, resize_to_limit: [ 1000, 1000 ], format: :webp
  end

  normalizes :name, with: ->(name) { name.squish }
  validates :name, presence: true, length: { maximum: 80 }

  # The products that offer it follow it as it changes, and stop offering it when it goes.
  after_update_commit :refresh_products
  before_destroy { @offering = products.to_a }
  after_destroy_commit { @offering.each(&:refresh_clipart) }

  scope :ordered, -> { order(:name) }

  # The products with a choice field that offers this set.
  def products
    Product.where("buyer_inputs @> ?", [ { "set" => id } ].to_json)
  end

  # Adds the images among the files, up to the most a choice field offers, and returns how many.
  def add_pictures(files)
    files = Array(files).select { |file| file.respond_to?(:content_type) && TYPES.include?(file.content_type.to_s) }
    files = files.first(MAX_PICTURES - pictures.count)
    return 0 if files.empty?

    pictures.attach(files)
    touch
    files.size
  end

  def room
    MAX_PICTURES - pictures.count
  end

  def remove_picture(picture)
    picture.purge
    touch
  end

  # The name buyers see under a picture.
  def rename_picture(picture, name)
    name = name.to_s.squish
    return false if name.blank? || name.length > 80

    picture.blob.update!(filename: "#{name}#{picture.filename.extension_with_delimiter}")
    touch
  end

  private
    def refresh_products
      products.find_each(&:refresh_clipart)
    end
end
