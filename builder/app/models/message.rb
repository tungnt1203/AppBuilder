# One entry in a chat with a project's agent: what the owner asked, what the agent said,
# the actions it took, and the summary of each turn.
class Message < ApplicationRecord
  belongs_to :chat, touch: true
  belongs_to :project, touch: true

  before_validation { self.project ||= chat&.project }

  enum :role, %w[ user assistant action plan result notice error ].index_by(&:itself)
end
