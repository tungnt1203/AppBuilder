# One publish of a project to ONCE: an image built from a commit, then deployed.
class Deployment < ApplicationRecord
  belongs_to :project, touch: true

  enum :status, %w[ building deploying live failed ].index_by(&:itself), default: "building"

  before_validation :assign_version_and_image, on: :create

  scope :latest_first, -> { order(version: :desc) }

  def in_progress?
    building? || deploying?
  end

  def append_log(text)
    update!(log: log + text.to_s)
  end

  private
    def assign_version_and_image
      self.version ||= project.deployments.maximum(:version).to_i + 1
      self.image ||= "#{Rails.configuration.x.registry}/#{project.slug}:v#{version}"
    end
end
