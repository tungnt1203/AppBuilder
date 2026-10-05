class PublishJob < ApplicationJob
  def perform(deployment)
    Publisher.new(deployment).publish
  end
end
