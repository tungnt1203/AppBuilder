require "open3"

# The requests bin/eval builds: many different owners, written by a model once and kept in
# eval/prompts.yml, so runs stay comparable. Each run builds a random sample of them (the
# same sample for the same seed), which says more about all the people using the builder
# than a few hand-picked cases would.
module Evaluation
  class Prompts
    FILE = Rails.root.join("eval/prompts.yml")
    MODEL = "sonnet"
    BUDGET_USD = 3
    TIMEOUT = 900 # seconds

    PROMPT = <<~TEXT
      Write %{count} requests that different people would type into an AI app builder, as their
      first message. The builder makes a small web app (Rails, with sign in, a database, email)
      that the person hosts for their business or group. Make them as varied as real users:

      - Who: shops, food and drink, beauty and health, trades and repairs, teaching, clubs and
        communities, nonprofits, events, rentals, freelancers, small offices and their internal
        tools, hobbies and families. No two the same kind; avoid the obvious examples.
      - How much they say: about a third one sentence, a third a short paragraph, a third
        detailed, with specifics (names, prices, opening hours, sections, rules, who may do what).
        Some detailed ones ask for a look that is unusual for their kind of business.
      - What they need: pages for their customers or the public, tools for themselves and staff,
        or both.
      - Language: about three quarters Vietnamese, written the way Vietnamese owners type
        (sometimes casual, short, with abbreviations or missing diacritics); the rest English.
      - Only what such an app can do on its own: no payments, no native mobile apps, no paid
        outside services.

      Each: {"name": "the app's name, as the owner would say it", "language": "vi" or "en",
      "request": "the message"}. Reply with only the JSON array.
    TEXT

    def self.all
      FILE.exist? ? YAML.load_file(FILE).map(&:with_indifferent_access) : []
    end

    def self.sample(count, seed:)
      all.sample(count, random: Random.new(seed))
    end

    def self.digest
      Digest::SHA256.file(FILE).hexdigest.first(8) if FILE.exist?
    end

    def self.generate(count)
      output, status = Timeout.timeout(TIMEOUT) do
        Open3.capture2e(AgentRunner.claude_env, "claude", "-p", format(PROMPT, count:), "--model", MODEL,
          "--output-format", "json", "--max-budget-usd", BUDGET_USD.to_s, "--tools", "", stdin_data: "")
      end
      raise "Writing prompts failed: #{output.last(1000)}" unless status.success?

      envelope = JSON.parse(output[/^\{.*\}$/m].to_s)
      prompts = begin
        JSON.parse(envelope["result"].to_s[/\[.*\]/m].to_s)
      rescue JSON::ParserError
        raise "The model's reply wasn't a JSON array: #{envelope["result"].to_s.first(1000)}"
      end
      prompts = prompts.select { |prompt| prompt["name"].present? && prompt["request"].present? && prompt["language"].in?(%w[ vi en ]) }
      write(prompts.each_with_index.map { |prompt, index| { "id" => format("p%03d", index + 1) }.merge(prompt.slice("name", "language", "request")) })
      [ prompts.size, envelope["total_cost_usd"] ]
    end

    def self.write(prompts)
      FILE.dirname.mkpath
      FILE.write(<<~YAML + prompts.to_yaml.delete_prefix("---\n"))
        # Requests bin/eval builds, written by `bin/eval generate` (Evaluation::Prompts).
        # Keep this file fixed: runs are only comparable on the same prompts. To change the
        # set, generate a new one and start a new baseline.
      YAML
    end
  end
end
