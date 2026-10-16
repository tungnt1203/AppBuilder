# A page the shop writes (about, FAQ, a story). The API serves published ones as blocks: the
# body, then the questions.
class Page < ApplicationRecord
  acts_as_tenant :shop

  include Sluggable

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 50_000 }
  validate :has_content

  normalizes :title, with: ->(title) { title.squish }

  before_validation :clean_faqs

  scope :published, -> { where(published: true) }

  def blocks
    text = { "type" => "text", "body" => body } if body.present?
    questions = { "type" => "faq", "items" => faqs } if faqs.any?
    [ text, questions ].compact
  end

  private
    def clean_faqs
      self.faqs = Array(faqs).filter_map { |row|
        row = row.stringify_keys
        question = row["question"].to_s.squish
        answer = row["answer"].to_s.strip
        next if question.blank? || answer.blank?

        { "question" => question.first(200), "answer" => answer.first(2_000) }
      }.first(40)
    end

    def has_content
      errors.add(:base, :empty) if body.blank? && faqs.blank?
    end
end
