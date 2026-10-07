require "test_helper"

class Evaluation::ReportTest < ActiveSupport::TestCase
  test "sums up a run and compares it with the one before" do
    previous = sample_run("20261005-1000", met: 1, cost: 3.0, passed: false)
    current = sample_run("20261006-1000", met: 3, cost: 2.5, passed: true)

    text = Evaluation::Report.new(current, previous: previous).to_text

    assert_match(/p001\s+built\s+6\/6\s+2\/3\s+3\/4\s+7/, text)
    assert_includes text, "asked %: 75.0 (+50.0 vs 20261005-1000)"
    assert_includes text, "prompts abcd1234  seed 1"
    assert_includes text, "tests passed: 1 (+1 vs 20261005-1000)"
    assert_includes text, "cost $: 2.6 (-0.5 vs 20261005-1000)"
  end

  test "leaves failed judging out of the scores" do
    data = sample_run("20261006-1000", met: 3, cost: 2, passed: true)
    data["cases"] << { "id" => "p002", "outcome" => "crashed", "judge" => { "error" => "timeout" } }

    assert_equal 75.0, Evaluation::Report.new(data).totals["asked %"]
    assert_equal 1, Evaluation::Report.new(data).totals["built"]
  end

  test "renders every screenshot in the html report" do
    html = Evaluation::Report.new(sample_run("20261006-1000", met: 3, cost: 2, passed: true)).to_html

    assert_includes html, %(src="shots/nail/visitor.png")
    assert_includes html, "projects/abc123"
    assert_includes html, "Không dùng màu hồng"
  end

  private
    def sample_run(id, met:, cost:, passed:)
      asked = [ "Đặt lịch không cần tài khoản", "Bảng giá", "Nền đen", "Không dùng màu hồng" ].each_with_index.map do |item, index|
        { "item" => item, "verdict" => index < met ? "met" : "missed", "why" => "" }
      end + [ { "item" => "Gửi email xác nhận", "verdict" => "unclear", "why" => "can't see emails" } ]

      { "id" => id, "builder" => "aaa", "template" => "bbb", "prompt" => "ccc", "prompts" => "abcd1234", "seed" => 1, "cases" => [ {
        "id" => "p001", "name" => "Tiệm nail Hoa", "project" => "abc123", "outcome" => "built", "cost_usd" => cost, "build_seconds" => 600,
        "tests" => { "passed" => passed, "runs" => 6, "failures" => passed ? 0 : 1, "errors" => 0 },
        "pages" => { "signed_in" => true, "visited" => [
          { "name" => "visitor", "path" => "/", "status" => 200, "file" => "shots/nail/visitor.png" },
          { "name" => "page-1", "path" => "/bookings", "status" => 200, "file" => "shots/nail/page-1.png" },
          { "name" => "page-2", "path" => "/reports", "status" => 500, "error" => "NoMethodError", "file" => "shots/nail/page-2.png" } ] },
        "judge" => { "asked" => asked, "look" => 7, "phone" => 6, "notes" => "Good.", "cost_usd" => 0.1 } } ] }
    end
end
