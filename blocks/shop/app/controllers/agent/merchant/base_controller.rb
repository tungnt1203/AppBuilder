# For the owner's assistant. The agent's host names the person it acts for in X-Agent-Operator
# (stamped on every change they stage, apply or discard).
class Agent::Merchant::BaseController < Agent::BaseController
  private
    def agent_role = "merchant"

    def merchant
      @merchant ||= AgentApi::Merchant.new
    end

    def operator
      request.headers["X-Agent-Operator"].presence&.truncate(100) or raise ActionController::ParameterMissing, "X-Agent-Operator header"
    end
end
