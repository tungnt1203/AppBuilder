# One message sent through a form. Answers are only the fields the form declares.
class FormSubmission < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :form

  validate :answers_match_the_form

  after_create_commit :notify_shop

  scope :newest, -> { order(created_at: :desc, id: :desc) }

  # raw is { "email" => "a@b.co" }. Returns false with errors when a field doesn't fit.
  def submit(raw)
    errors.clear
    raw = case raw
    when ActionController::Parameters then raw.to_unsafe_h
    when Hash then raw
    else {}
    end.stringify_keys
    collected = {}
    form.fields.each do |field|
      value = raw[field["key"]]
      value = field["type"] == "boolean" ? ActiveModel::Type::Boolean.new.cast(value) == true : value.to_s.strip
      if field["type"] == "boolean"
        errors.add(field["key"], "must be accepted") if field["required"] && value != true
      elsif value.blank?
        errors.add(field["key"], "can't be blank") if field["required"]
      elsif field["type"] == "email" && !value.match?(ApplicationRecord::EMAIL_FORMAT)
        errors.add(field["key"], "is invalid")
      elsif value.length > (field["type"] == "textarea" ? 5_000 : 500)
        errors.add(field["key"], "is too long")
      end
      collected[field["key"]] = value if field["type"] == "boolean" || value.present?
    end
    self.answers = collected
    errors.empty? && save
  end

  def lines
    form.fields.filter_map do |field|
      next unless answers.key?(field["key"])

      value = answers[field["key"]]
      value = value ? "Yes" : "No" if field["type"] == "boolean"
      "#{field["label"]}: #{value}"
    end
  end

  private
    def answers_match_the_form
      # submit adds the field errors; a submission built another way still needs answers that fit.
      return if errors.any? || answers.blank?

      unknown = answers.keys - form.fields.map { |field| field["key"] }
      errors.add(:base, "has a field the form doesn't ask for") if unknown.any?
    end

    def notify_shop
      Admin::FormMailer.submission(self).deliver_later
    end
end
