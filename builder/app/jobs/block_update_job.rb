# Brings an app's blocks (vendor/blocks/shop…) up to the latest, when its owner asks: the new
# copy, its migrations, then the app's tests. The update is a version of its own, so the owner
# can go back. When the app's own code no longer works with the new core (its tests fail), the
# agent fixes the app's code in a turn of its own, as the owner asked for a working update.
class BlockUpdateJob < ApplicationJob
  def perform(project)
    blocks = project.blocks
    changes = blocks.updates
    names = blocks.update!
    return project.update!(status: :ready, activity: nil) if names.empty?

    title = blocks.titles(names)
    project.update!(activity: "Updating the #{title}")
    project.sandbox.run("sh", "-c", "bundle check > /dev/null || bundle install --quiet")
    project.sandbox.run("bin/rails", "db:migrate")
    project.history.commit("Update the #{title}")
    project.restart_preview
    project.messages.create!(role: :notice, body: "Updated the #{title}", data: { "sha" => project.history.current_sha, "tree" => project.history.current_tree })

    project.update!(activity: "Running the app's tests")
    output, passed = project.sandbox.capture("bin/rails", "test")
    note = agent_note(names, changes)
    if passed
      project.update!(status: :ready, activity: nil, agent_note: [ project.agent_note, note ].compact.join("\n\n"))
    else
      AgentTurnJob.perform_later(project, [ note, fix_request(output) ].join("\n\n"), "build")
    end
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: error.message.truncate(4000))
    project.update!(status: :failed)
  end

  private
    def agent_note(names, changes)
      list = names.flat_map { |name| changes[name].to_a.first(15).map { |change| "- #{change}" } }
      [ "Since your last turn the owner updated #{names.map { |name| "vendor/blocks/#{name}" }.to_sentence} to the latest version. " \
        "Read the core again before you rely on it.", (list.any? ? "What changed:\n#{list.join("\n")}" : nil) ].compact.join("\n")
    end

    def fix_request(output)
      "With the new core, the app's tests fail. Fix the app's own code so they pass again (never change vendor/blocks), " \
        "keeping what the owner built. The failures:\n\n#{output.last(6000)}"
    end
end
