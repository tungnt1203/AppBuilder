# Moves a published app to its new address on ONCE. Its container and data stay;
# only the host it answers to changes.
class MoveJob < ApplicationJob
  def perform(project, subdomain)
    old_host, new_host = project.publish_host, project.host_for(subdomain)
    project.shell.run(Rails.configuration.x.once_bin, "update", old_host, "--host", new_host)
    project.update!(subdomain: subdomain, status: :ready, activity: nil)
    project.messages.create!(role: :notice, body: "Moved to #{project.publish_url}. Links to #{old_host} no longer work, " \
      "and people signed in to the app need to sign in again.")
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: "The app couldn't move and is still at #{old_host}.\n\n#{error.message.truncate(4000)}")
    project.update!(status: :ready, activity: nil)
  end
end
