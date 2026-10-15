require "open3"

# The requests bin/eval builds: many different print-on-demand sellers, written once and kept in
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
      Write %{count} requests that different people would type into an AI shop builder, as their
      first message. The builder makes a print-on-demand shop (products made in Printify: tees,
      hoodies, mugs, posters, totes…) that sells to buyers who come from Facebook or TikTok ads,
      mostly on phones. Make them as varied as real sellers:

      - What they sell: a niche each (a hobby, a job, a pet, a city, a fandom-free joke, a cause,
        a family event), never two the same; avoid the obvious examples.
      - How much they say: about a third one sentence, a third a short paragraph, a third
        detailed, with specifics (the shop's name, products, prices, colors, free shipping, sizes,
        collections, the look they want). Some ask for a look that is unusual for their niche.
      - Language: about three quarters Vietnamese, written the way Vietnamese sellers type
        (sometimes casual, short, with abbreviations or missing diacritics); the rest English.
        Their buyers are in the US or Europe, so the shop is in English either way.
      - Only what the builder's shop can do: no marketplaces, no native mobile apps, no paid
        outside services beyond Stripe, Printify and their ad pixels.

      Each: {"name": "the shop's name, as the owner would say it", "language": "vi" or "en",
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
