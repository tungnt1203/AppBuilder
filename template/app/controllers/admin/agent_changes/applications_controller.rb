class Admin::AgentChanges::ApplicationsController < Admin::BaseController
  def create
    change = AgentChange.find(params[:agent_change_id])
    change.apply!(by: Current.user.name)
    redirect_to admin_agent_changes_path, notice: t(".notice"), status: :see_other
  rescue AgentChange::NotApplicable, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to admin_agent_changes_path, alert: t(".failed", error: error.message), status: :see_other
  end
end
