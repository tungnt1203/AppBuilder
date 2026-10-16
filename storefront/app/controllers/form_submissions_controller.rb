# A form of the theme's (config/forms.yml) sent to the shop: it lands in the admin's inbox and the
# owner's email. Back to the page it came from.
class FormSubmissionsController < ApplicationController
  rate_limit to: 5, within: 1.minute, with: -> { redirect_back_or_to root_path, alert: t("form_submissions.rate_limited") }

  def create
    answers = params[:answers].respond_to?(:permit) ? params[:answers].permit!.to_h : {}
    storefront.submit_form(params[:form_key], answers, idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid)
    redirect_back_or_to root_path, notice: t(".sent")
  rescue StorefrontKit::Invalid => error
    redirect_back_or_to root_path, alert: error.fields.map { |field, message| "#{field.humanize} #{message}" }.to_sentence.presence || error.message
  end
end
