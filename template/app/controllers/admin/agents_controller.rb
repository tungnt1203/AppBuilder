# AI agents connected to the shop through its agent API (/agent/v1): a shopping assistant for
# buyers and the owner's assistant. Admins make a key for each and give it to where the agent
# runs (see integrations/commerce-agents in AppBuilder); a new key replaces the old one.
class Admin::AgentsController < Admin::BaseController
  before_action :require_administrator

  def show
    @store = Store.current
    @new_key = flash[:agent_key]
  end

  def create
    role = params.expect(:role)
    key = Store.current.generate_agent_key!(role)
    redirect_to admin_agents_path, notice: t(".notice.#{role}"), flash: { agent_key: { "role" => role, "key" => key } }
  end

  def destroy
    role = params.expect(:role)
    Store.current.revoke_agent_key!(role)
    redirect_to admin_agents_path, notice: t(".notice.#{role}"), status: :see_other
  end
end
