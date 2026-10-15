# For the API's POSTs that must not happen twice (placing an order, starting a payment):
# `idempotent { … render … }` runs the block once per Idempotency-Key header and answers a
# repeat with the first answer (ApiIdempotencyKey). Without the header, the block just runs.
module StorefrontApi::Idempotent
  private
    def idempotent
      key = request.headers["Idempotency-Key"].to_s.strip
      return yield if key.empty?

      fingerprint = ApiIdempotencyKey.fingerprint(request)
      record = begin
        ApiIdempotencyKey.create!(key: key.first(255), fingerprint:)
      rescue ActiveRecord::RecordNotUnique
        return repeat(ApiIdempotencyKey.find_by!(key: key.first(255)), fingerprint)
      end

      yield
      if response.status < 500
        record.update!(response_status: response.status, response_body: JSON.parse(response.body))
      else
        record.destroy!
      end
    rescue StandardError
      record&.destroy! unless record&.answered?
      raise
    end

    def repeat(record, fingerprint)
      if record.fingerprint != fingerprint
        error :idempotency_key_reused, "That Idempotency-Key was used for another request", status: :unprocessable_entity
      elsif !record.answered?
        error :in_progress, "The first request with that Idempotency-Key is still being handled", status: :conflict
      else
        response.headers["Idempotent-Replayed"] = "true"
        render json: record.response_body, status: record.response_status
      end
    end
end
