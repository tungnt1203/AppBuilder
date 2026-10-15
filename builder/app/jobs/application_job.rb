class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # The owner can delete an app while jobs for it are still queued.
  discard_on ActiveJob::DeserializationError

  # A job enqueued inside a shop (ActsAsTenant.current_tenant) runs inside it, its records
  # loaded there too; jobs for every shop (the recurring ones) go through Shop.each_in_turn.
  attr_accessor :shop_id

  def serialize
    super.merge("shop_id" => shop_id || ActsAsTenant.current_tenant&.id)
  end

  def deserialize(job_data)
    super
    self.shop_id = job_data["shop_id"]
  end

  def perform_now
    shop = ActsAsTenant.without_tenant { Shop.find_by(id: shop_id) } if shop_id
    shop ? ActsAsTenant.with_tenant(shop) { super } : super
  end
end
