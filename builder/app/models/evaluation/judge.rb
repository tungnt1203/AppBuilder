require "open3"

# Asks a model to look at an app's screenshots, next to the owner's request, and judge it
# the way the owner would: each thing they asked for, met or missed, and scores from 1 to
# 10 for the look and for phones.
module Evaluation
  class Judge
    MODEL = "sonnet"
    BUDGET_USD = 1
    TIMEOUT = 300 # seconds
    SCORES = %w[ look phone ]
    VERDICTS = %w[ met missed unclear ]

    PROMPT = <<~TEXT
      You are reviewing an app that an AI app builder made for someone who can't program. Read
      each screenshot listed below with the Read tool, then judge the app as that person would
      on first use. Empty lists are expected (there's no data yet); judge whether the empty
      states help. Pages are captured whole, top to bottom, so a fixed or sticky bar can show
      up in the middle of a capture; that isn't a problem in the app.

      First list what the person explicitly asked for: every concrete thing in their request (a
      screen, a feature, a rule, who may do what, content such as names, prices and hours,
      anything about the look). Only what they said, not what such apps usually have; one item
      each, short, in the request's language. Decide each one:
      - "met": the screenshots show it.
      - "missed": the screenshots show it isn't so, or it's absent where it would show.
      - "unclear": screenshots can't show it (a rule checked on save, an email sent).

      Then score from 1 (bad) to 10 (excellent):
      - look: is it polished, clear and consistent, with its own look rather than a default template?
      - phone: do the phone screenshots work well on a small screen?

      Reply with only this JSON:
      {"asked": [{"item": "...", "verdict": "met", "why": "a few words"}], "look": 0, "phone": 0,
       "notes": "two or three sentences: the biggest problems, most important first"}
    TEXT

    # Share of what was asked that the app visibly does, leaving out what can't be seen.
    def self.asked_rate(judge)
      verdicts = Array(judge&.dig("asked")).map { |item| item["verdict"] }
      judged = verdicts.count { |verdict| verdict.in?(%w[ met missed ]) }
      (100.0 * verdicts.count("met") / judged).round if judged.positive?
    end

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
      asked = Array(scores["asked"]).select { |item| item.is_a?(Hash) && item["verdict"].in?(VERDICTS) }
      scores.slice(*SCORES, "notes").merge("asked" => asked, "cost_usd" => envelope["total_cost_usd"]&.round(3))
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
          The request (#{@case[:language]}):
          #{@case[:request].strip}

          What the builder replied when it finished:
          #{@reply.to_s.strip.presence || "(nothing)"}

          Screenshots:
          #{shots.join("\n")}
        TEXT
      end
  end
end
