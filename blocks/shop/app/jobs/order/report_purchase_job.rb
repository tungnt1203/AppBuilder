# Sends a placed order to Meta's Conversions API (Meta::Purchase). Meta down or busy: tried again
# for about an hour. A token Meta refuses isn't tried again; the owner sees it in Settings.
class Order::ReportPurchaseJob < ApplicationJob
  retry_on MetaGateway::Error, wait: :polynomially_longer, attempts: 5 do |job, error|
    Rails.logger.warn "Couldn't send order #{job.arguments.first.number} to Meta: #{error.message}"
  end

  discard_on MetaGateway::TokenError do |job, error|
    Store.current.update_columns(meta_error: error.message)
  end

  def perform(order)
    Meta::Purchase.new(order).report!
  end
end
