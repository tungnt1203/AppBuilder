# The agent API (/agent/v1): what AI agents built on anthropics/commerce-agents call, with the
# shop's own key for their role (Store#generate_agent_key!) as a bearer token. JSON only; the
# rules are the shop's, the same as for its screens.
class Agent::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_agent

  rescue_from ActiveRecord::RecordNotFound do |error|
    render json: { error: "not_found", message: error.message }, status: :not_found
  end
  rescue_from AgentChange::NotApplicable do |error|
    render json: { error: "not_applicable", message: error.message }, status: :unprocessable_entity
  end
  rescue_from ActionController::ParameterMissing do |error|
    render json: { error: "bad_request", message: error.message }, status: :bad_request
  end

  private
    def agent_role = raise(NotImplementedError)

    def authenticate_agent
      authenticate_with_http_token { |key, _options| Store.current.agent_key_valid?(agent_role, key) } ||
        render(json: { error: "unauthorized", message: "A valid #{agent_role} agent key is needed" }, status: :unauthorized)
    end

    def store = Store.current

    def url_options_for_links
      { host: request.host, port: (request.port unless request.port.in?([ 80, 443 ])), protocol: request.protocol }.compact
    end
end
