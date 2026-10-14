# Brings an app up to the latest, when its owner asks: its blocks (vendor/blocks/shop…) and the
# template's changes since its code was made (ProjectTemplate). What can be taken as it is goes
# in straight away, as a version of its own the owner can go back from, with the core's
# migrations; then the app's tests run. The agent finishes in a turn of its own when files the
# app changed need the template's changes worked in, or when the app's tests fail.
class ProjectUpdateJob < ApplicationJob
  def perform(project)
    blocks, template = project.blocks, project.template
    block_changes, template_changes = blocks.updates, template.changes
    names = blocks.update!
    result = template.apply!
    title = project.update_title(names, result.updated.any? || result.left?)

    project.update!(activity: "Updating the #{title}")
    project.sandbox.run("sh", "-c", "bundle check > /dev/null || bundle install --quiet")
    project.sandbox.run("bin/rails", "db:migrate")
    project.history.commit("Update the #{title}")
    project.restart_preview
    project.messages.create!(role: :notice, body: "Updated the #{title}#{" — the agent is bringing in the rest" if result.left?}",
      data: { "sha" => project.history.current_sha, "tree" => project.history.current_tree })

    project.update!(activity: "Running the app's tests")
    output, passed = project.sandbox.capture("bin/rails", "test")
    note = agent_note(names, block_changes, template_changes, result)

    if result.left? || !passed
      AgentTurnJob.perform_later(project, [ note, finish_request(result, passed ? nil : output) ].compact.join("\n\n"), "build")
    else
      project.update!(status: :ready, activity: nil, agent_note: [ project.agent_note, note ].compact.join("\n\n"))
    end
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: error.message.truncate(4000))
    project.update!(status: :failed)
  end

  private
    def agent_note(names, block_changes, template_changes, result)
      lines = [ "Since your last turn the owner updated the app to the latest version of the template it was made from." ]
      if names.any?
        lines << "#{names.map { |name| "vendor/blocks/#{name}" }.to_sentence} changed; read the core again before you rely on it."
        lines += names.flat_map { |name| block_changes[name].to_a.first(15).map { |change| "- #{change}" } }
      end
      if template_changes.any?
        lines << "What's new in the template:"
        lines += template_changes.first(20).map { |change| "- #{change}" }
      end
      lines << "These files were taken from the template as they are (the app hadn't changed them): #{result.updated.first(40).join(", ")}." if result.updated.any?
      lines << "Read CLAUDE.md again: it may describe new built-in parts." if result.updated.include?("CLAUDE.md")
      lines << "Updating changes the app's code, never its data: don't delete or reset records in its database " \
        "(the owner's products, orders and settings are there), even when the template now seeds things differently."
      lines.join("\n")
    end

    def finish_request(result, test_output)
      parts = []
      if result.left?
        parts << "These files of the app were changed for the owner, so the template's changes to them weren't taken. " \
          "Bring each change into the app's version, keeping the owner's design, copy and what they asked for " \
          "(SPEC.md), so the app gets the template's new features and fixes. The template's diff of each file is in " \
          "#{ProjectTemplate::DIFFS}/<file>.diff:\n#{result.left.map { |path| "- #{path}" }.join("\n")}"
      end
      parts << "With the new version, the app's tests fail. Fix the app's own code so they pass again (never change vendor/blocks). " \
        "The failures:\n\n#{test_output.last(6000)}" if test_output
      parts << "Then run the tests and look at the pages you changed, as usual. Delete #{ProjectTemplate::DIFFS} when you're done." if result.left?
      parts.join("\n\n")
    end
end
