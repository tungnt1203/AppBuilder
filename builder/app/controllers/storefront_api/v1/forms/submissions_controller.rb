# A message sent through one of the shop's forms. Idempotent with an Idempotency-Key, so a
# double tap doesn't send it twice. The shop is emailed.
class StorefrontApi::V1::Forms::SubmissionsController < StorefrontApi::V1::BaseController
  include StorefrontApi::Idempotent

  def create
    form = Form.find_by!(key: params[:form_key])
    idempotent do
      submission = form.submissions.build
      if submission.submit(raw_answers)
        render json: { submission: { id: submission.id } }, status: :created
      else
        invalid submission
      end
    end
  end

  private
    def raw_answers
      value = params[:answers]
      case value
      when ActionController::Parameters then value.to_unsafe_h
      when Hash then value
      else {}
      end
    end
end
