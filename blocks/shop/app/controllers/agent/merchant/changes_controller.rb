# Staged changes: the assistant proposes (create), the owner approves (apply) or not (discard).
class Agent::Merchant::ChangesController < Agent::Merchant::BaseController
  def index
    render json: { changes: AgentChange.staged.newest_first.map(&:as_contract_json) }
  end

  def create
    change = AgentChange.stage!(params.require(:kind), params.require(:payload).to_unsafe_h, by: operator, by_kind: params.fetch(:actor_kind, "agent"))
    render json: change.as_contract_json, status: :created
  end

  def apply
    render json: find_change.tap { |change| change.apply!(by: operator) }.as_contract_json
  end

  def discard
    render json: find_change.tap { |change| change.discard!(by: operator, by_kind: params.fetch(:actor_kind, "operator")) }.as_contract_json
  end

  private
    def find_change
      AgentChange.find_by_change_id!(params[:id])
    end
end
