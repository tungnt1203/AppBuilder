# Sums up an eval run, next to the run before it: a table for the terminal and
# report.html with every screenshot.
module Evaluation
  class Report
    def initialize(data, previous: nil)
      @data, @previous = data, previous
    end

    def self.for(id)
      ids = Run.ids
      previous = ids[ids.index(id) - 1] if ids.index(id).to_i.positive?
      new(Run.load(id), previous: previous && Run.load(previous))
    end

    def totals(data = @data)
      cases = data["cases"]
      judged = cases.filter_map { |result| result["judge"] unless result.dig("judge", "error") }
      {
        "built" => cases.count { |result| result["outcome"] == "built" },
        "tests passed" => cases.count { |result| result.dig("tests", "passed") },
        "pages ok" => cases.sum { |result| ok_pages(result) },
        "fit" => average(judged.map { |judge| judge["fit"] }),
        "look" => average(judged.map { |judge| judge["look"] }),
        "phone" => average(judged.map { |judge| judge["phone"] }),
        "cost $" => cases.sum { |result| result["cost_usd"].to_f + result.dig("judge", "cost_usd").to_f }.round(2),
        "median min" => median(cases.filter_map { |result| result["build_seconds"] }.map { |seconds| seconds / 60.0 })
      }
    end

    def to_text
      header = [ "case", "outcome", "tests", "pages", "fit", "look", "phone", "$", "min" ]
      rows = @data["cases"].map do |result|
        judge = result["judge"] || {}
        [ result["id"], result["outcome"], tests_text(result), "#{ok_pages(result)}/#{result.dig("pages", "visited")&.size.to_i}",
          judge["fit"], judge["look"], judge["phone"], result["cost_usd"], result["build_seconds"] && (result["build_seconds"] / 60.0).round(1) ].map(&:to_s)
      end
      widths = header.each_index.map { |index| ([ header ] + rows).map { |row| row[index].size }.max }
      line = ->(row) { row.each_with_index.map { |cell, index| cell.ljust(widths[index]) }.join("  ") }

      summary = totals.map do |name, value|
        before = @previous && totals(@previous)[name]
        change = before && value && before != value ? " (#{format_change(value - before)} vs #{@previous["id"]})" : ""
        "#{name}: #{value}#{change}"
      end

      [ "Run #{@data["id"]}  builder #{@data["builder"]}  template #{@data["template"]}  prompt #{@data["prompt"]}  #{@data["note"]}".strip,
        "", line.(header), *rows.map(&line), "", *summary ].join("\n")
    end

    def to_html
      ApplicationController.render(template: "evaluation/report", layout: false, assigns: { data: @data, previous: @previous, report: self })
    end

    def write(dir)
      dir.join("report.html").write(to_html)
      dir.join("report.txt").write(to_text)
    end

    def ok_pages(result)
      Array(result.dig("pages", "visited")).count { |page| page["status"].to_i.between?(200, 399) && page["error"].blank? }
    end

    def tests_text(result)
      tests = result["tests"] or return ""
      return "error" unless tests["runs"]
      "#{tests["runs"] - tests["failures"] - tests["errors"]}/#{tests["runs"]}"
    end

    private
      def average(values)
        values = values.compact
        (values.sum.to_f / values.size).round(1) if values.any?
      end

      def median(values)
        sorted = values.sort
        sorted[sorted.size / 2]&.round(1)
      end

      def format_change(change)
        change = change.round(2)
        change.positive? ? "+#{change}" : change.to_s
      end
  end
end
