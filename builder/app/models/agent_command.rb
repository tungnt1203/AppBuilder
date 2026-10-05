# Something the owner tells the agent while it's working: an answer to its
# question, an extra message, or Stop. The running turn delivers these to the
# agent process (see AgentRunner), so they work across processes.
class AgentCommand < ApplicationRecord
  belongs_to :project

  enum :kind, %w[ answer message interrupt ].index_by(&:itself)

  scope :pending, -> { where(delivered_at: nil).order(:id) }

  def to_line
    payload.merge("type" => kind).to_json
  end

  def delivered!
    update!(delivered_at: Time.current)
  end
end
