# A unique, readable address from the title (/products/cat-mom-tee), kept when the title changes
# so links shared earlier keep working. to_param is the slug.
module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :assign_slug
    validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  end

  def to_param
    slug_was.presence || slug
  end

  private
    def assign_slug
      self.slug = slug.to_s.parameterize.presence
      self.slug ||= unique_slug_from(title)
    end

    def unique_slug_from(text)
      base = text.to_s.parameterize.presence || self.class.model_name.singular
      candidate, suffix = base, 1
      while self.class.where.not(id: id).exists?(slug: candidate)
        suffix += 1
        candidate = "#{base}-#{suffix}"
      end
      candidate
    end
end
