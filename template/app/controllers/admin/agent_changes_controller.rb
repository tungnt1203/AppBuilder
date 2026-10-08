# What the owner's assistant proposed, waiting for someone to apply or discard it.
class Admin::AgentChangesController < Admin::BaseController
  def index
    @staged = AgentChange.staged.newest_first
    @recent = AgentChange.where.not(status: "staged").newest_first.limit(20)
  end
end
