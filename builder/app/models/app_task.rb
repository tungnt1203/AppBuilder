# Runs one of the shop core's tasks (`bin/rails shop:…`) in an app, where it runs: its preview,
# or its published copy on ONCE (`once exec`). The task prints its answer as JSON after a marker
# line; input, often secret, goes in a variable (preview) or on stdin (ONCE), never in arguments.
# Returns the answer, or { "errors" => [why] }.
class AppTask
  def initialize(project)
    @project = project
  end

  def run(task, marker:, copy: :preview, input: nil)
    output, succeeded = copy == :live ? live(task, input) : preview(task, input)
    line = output.to_s.lines.reverse.find { |each| each.start_with?(marker) }
    return JSON.parse(line.delete_prefix(marker).strip) if succeeded && line

    reason = output.to_s.match?(/Don't know how to build task|Unrecognized command/) ? "Update the app first (its shop core is older)" : output.to_s.strip.last(300)
    { "errors" => [ reason.presence || "It didn't answer" ] }
  rescue JSON::ParserError
    { "errors" => [ "Its answer couldn't be read" ] }
  end

  private
    def preview(task, input)
      @project.sandbox.capture("bin/rails", task, env: input ? { "TASK_INPUT" => input } : {})
    end

    def live(task, input)
      script = %(TASK_INPUT="$(cat)" exec bin/rails #{task})
      ProjectShell.new(@project.path).capture(Rails.configuration.x.once_bin, "exec", @project.publish_host, "sh", "-c", script, stdin: input.to_s)
    end
end
