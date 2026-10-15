# Starts and ends every shop's sales on time (config/recurring.yml runs it every five minutes).
class Promotion::SyncJob < ApplicationJob
  def perform(now = Time.current)
    Shop.each_in_turn do
      Promotion.due_to_end(now).find_each(&:finish!)
      Promotion.due_to_start(now).find_each { |promotion| promotion.start!(now) }
    end
  end
end
