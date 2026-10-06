class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # The owner can delete an app while jobs for it are still queued.
  discard_on ActiveJob::DeserializationError
end
