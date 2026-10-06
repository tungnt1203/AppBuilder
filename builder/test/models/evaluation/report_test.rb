require "test_helper"

class Evaluation::ReportTest < ActiveSupport::TestCase
  test "sums up a run and compares it with the one before" do
    previous = sample_run("20261005-1000", fit: 6, cost: 3.0, passed: false)
    current = sample_run("20261006-1000", fit: 8, cost: 2.5, passed: true)

    text = Evaluation::Report.new(current, previous: previous).to_text

    assert_match(/nail\s+built\s+6\/6\s+2\/3\s+8/, text)
    assert_includes text, "fit: 8.0 (+2.0 vs 20261005-1000)"
    assert_includes text, "tests passed: 1 (+1 vs 20261005-1000)"
    assert_includes text, "cost $: 2.6 (-0.5 vs 20261005-1000)"
  end

  test "leaves failed judging out of the scores" do
    data = sample_run("20261006-1000", fit: 8, cost: 2, passed: true)
    data["cases"] << { "id" => "gym", "outcome" => "crashed", "judge" => { "error" => "timeout" } }

    assert_equal 8.0, Evaluation::Report.new(data).totals["fit"]
    assert_equal 1, Evaluation::Report.new(data).totals["built"]
  end

  test "renders every screenshot in the html report" do
    html = Evaluation::Report.new(sample_run("20261006-1000", fit: 8, cost: 2, passed: true)).to_html

    assert_includes html, %(src="shots/nail/visitor.png")
    assert_includes html, "projects/abc123"
  end

  private
    def sample_run(id, fit:, cost:, passed:)
      { "id" => id, "builder" => "aaa", "template" => "bbb", "prompt" => "ccc", "cases" => [ {
        "id" => "nail", "name" => "Tiệm nail Hoa", "project" => "abc123", "outcome" => "built", "cost_usd" => cost, "build_seconds" => 600,
        "tests" => { "passed" => passed, "runs" => 6, "failures" => passed ? 0 : 1, "errors" => 0 },
        "pages" => { "signed_in" => true, "visited" => [
          { "name" => "visitor", "path" => "/", "status" => 200, "file" => "shots/nail/visitor.png" },
          { "name" => "page-1", "path" => "/bookings", "status" => 200, "file" => "shots/nail/page-1.png" },
          { "name" => "page-2", "path" => "/reports", "status" => 500, "error" => "NoMethodError", "file" => "shots/nail/page-2.png" } ] },
        "judge" => { "fit" => fit, "look" => 7, "phone" => 6, "notes" => "Good.", "cost_usd" => 0.1 } } ] }
    end
end
