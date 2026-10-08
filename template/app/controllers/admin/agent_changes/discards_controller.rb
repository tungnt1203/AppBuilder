class Admin::AgentChanges::DiscardsController < Admin::BaseController
  def create
    AgentChange.find(params[:agent_change_id]).discard!(by: Current.user.name)
    redirect_to admin_agent_changes_path, notice: t(".notice"), status: :see_other
  rescue AgentChange::NotApplicable => error
    redirect_to admin_agent_changes_path, alert: error.message, status: :see_other
  end
end
