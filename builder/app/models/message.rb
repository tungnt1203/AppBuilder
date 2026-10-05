# One entry in a project's chat: what the owner asked, what the agent said,
# the actions it took, and the summary of each turn.
class Message < ApplicationRecord
  belongs_to :project, touch: true

  enum :role, %w[ user assistant action result error ].index_by(&:itself)
end
