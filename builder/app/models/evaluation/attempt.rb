# Builds one sample request as a real project and measures the outcome: whether the
# build finished, what it cost and how long it took, the app's own tests and lint,
# which pages open (Evaluation::Inspection) and how they look (Evaluation::Judge).
module Evaluation
  class Attempt
    # Nobody answers during a run, so the agent builds right away. The studio's first
    # turn plans and may ask instead; this measures the build.
    NOTE = "Build this now without asking anything: nobody can answer questions during this run. " \
           "Where the request leaves something open, pick what suits this kind of business best."

    attr_reader :project

    def initialize(run, eval_case)
      @run, @case = run, eval_case
    end

    def create_project
      @project = Project.create!(name: @case[:name], language: @case[:language], eval_run: @run.id)
      @project.messages.create!(role: :user, body: @case[:request])
    end

    def call
      result = { "id" => @case[:id], "name" => @case[:name], "project" => project.slug }
      started = monotonic

      ProjectSetupJob.perform_now(project)
      return result.merge("outcome" => "setup failed", "error" => last_error) unless project.reload.ready?

      AgentTurnJob.perform_now(project, [ @case[:request], NOTE ].join("\n\n"), "build")
      project.reload
      result.merge!(turn, "outcome" => outcome, "build_seconds" => (monotonic - started).round)
      result.merge!("tests" => tests, "rubocop" => rubocop, "files_changed" => files_changed)

      if project.preview_running?
        inspection = Inspection.new(project, @run.dir.join("shots", @case[:id])).call
        result["pages"] = inspection.pages
        result["judge"] = Judge.new(@case, inspection, reply: project.messages.assistant.last&.body).call
      end
      result
    rescue => error
      result.merge("outcome" => "crashed", "error" => "#{error.class}: #{error.message}".truncate(2000))
    ensure
      project&.preview&.stop
    end

    private
      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def turn
        summary = project.messages.where(role: %w[ result error ]).where.not(data: {}).last&.data || {}
        { "cost_usd" => summary["total_cost_usd"]&.round(2), "agent_turns" => summary["num_turns"],
          "agent_seconds" => summary["duration_ms"] && (summary["duration_ms"] / 1000.0).round,
          "preview_error" => project.preview_error }
      end

      def outcome
        if project.messages.assistant.last&.data&.dig("questions").present? then "asked"
        elsif project.failed? then "failed"
        elsif project.preview_broken? then "broken preview"
        else "built"
        end
      end

      def last_error
        project.messages.error.last&.body.to_s.truncate(2000)
      end

      def tests
        output, passed = project.sandbox.capture("bin/rails", "test")
        counts = output.scan(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/).last&.map(&:to_i)
        result = { "passed" => passed }
        result.merge!(%w[ runs assertions failures errors ].zip(counts).to_h) if counts
        result["output"] = output.last(3000) unless passed
        result
      end

      def rubocop
        output, = project.sandbox.capture("bin/rubocop", "--format", "json")
        JSON.parse(output[/\{.*\}/m].to_s).dig("summary", "offense_count")
      rescue JSON::ParserError
        nil
      end

      def files_changed
        output, = project.shell.capture("git", "diff", "--name-only", project.base_sha.to_s, "HEAD")
        output.lines.size
      end
  end
end
