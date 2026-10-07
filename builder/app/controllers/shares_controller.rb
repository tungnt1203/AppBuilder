# A shared preview link: whoever has it can try the app, without an account. It leads
# through the preview's gate like the studio does (see PreviewGate).
class SharesController < ApplicationController
  allow_unauthenticated_access

  def show
    project = Project.find_by!(share_token: params[:token])

    if project.preview.running?
      redirect_to project.preview_gate.entry_url, allow_other_host: true
    else
      project.ensure_preview
      render :starting, layout: "authentication", status: :service_unavailable
    end
  end
end
