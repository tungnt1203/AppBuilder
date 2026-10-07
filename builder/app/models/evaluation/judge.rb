require "open3"

# Asks a model to look at an app's screenshots, next to the owner's request, and
# score it the way the owner would see it. Scores are 1 to 10.
module Evaluation
  class Judge
    MODEL = "sonnet"
    BUDGET_USD = 1
    TIMEOUT = 300 # seconds
    SCORES = %w[ fit look phone ]

    PROMPT = <<~TEXT
      You are reviewing an app that an AI app builder made for a small business owner who
      can't program. Read each screenshot listed below with the Read tool, then judge the app
      as that owner would on first use. Empty lists are expected (there's no data yet); judge
      whether the empty states help. Pages are captured whole, top to bottom, so a fixed or
      sticky bar can show up in the middle of a capture; that isn't a problem in the app.

      Score each from 1 (bad) to 10 (excellent):
      - fit: does it do what the owner asked, with the screens they'd expect, and look the way they asked?
      - look: is it polished, clear and consistent, with its own look rather than a default template?
      - phone: do the phone screenshots work well on a small screen?

      Reply with only this JSON:
      {"fit": 0, "look": 0, "phone": 0, "notes": "two or three sentences: the biggest problems, most important first"}
    TEXT

    def initialize(eval_case, inspection, reply:)
      @case, @inspection, @reply = eval_case, inspection, reply
    end

    def call
      output, status = Timeout.timeout(TIMEOUT) do
        Open3.capture2e(AgentRunner.claude_env, *command, chdir: Run::ROOT.to_s, stdin_data: "")
      end
      return { "error" => output.last(1000) } unless status.success?

      envelope = JSON.parse(output)
      scores = JSON.parse(envelope["result"].to_s[/\{.*\}/m].to_s)
      scores.slice(*SCORES, "notes").merge("cost_usd" => envelope["total_cost_usd"]&.round(3))
    rescue JSON::ParserError, Timeout::Error => error
      { "error" => "#{error.class}: #{output.to_s.last(1000)}" }
    end

    private
      def command
        [ "claude", "-p", prompt, "--model", MODEL, "--output-format", "json",
          "--allowedTools", "Read", "--max-budget-usd", BUDGET_USD.to_s ]
      end

      def prompt
        shots = @inspection.shots.select { |shot| shot.file.exist? }.map do |shot|
          who = shot.signed_in ? "signed in as the owner" : "a visitor, not signed in"
          who = "on a phone, #{who}" if shot.name.start_with?("phone")
          "- #{shot.file} — #{shot.path} (#{who}#{", #{shot.error}" if shot.error})"
        end

        <<~TEXT
          #{PROMPT}
          The owner's request (#{@case[:language]}):
          #{@case[:request].strip}

          What the builder told the owner when it finished:
          #{@reply.to_s.strip.presence || "(nothing)"}

          Screenshots:
          #{shots.join("\n")}
        TEXT
      end
  end
end
