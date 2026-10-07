require "test_helper"

class PointedElementTest < ActiveSupport::TestCase
  test "reads what the preview probe sends and describes it for the agent" do
    pointed = PointedElement.from_param({ page: "/", selector: "main > section:nth-of-type(2) > a.btn", tag: "a", text: "Đặt lịch ngay",
                                          html: %(<a class="btn" href="/dat-lich/new">Đặt lịch ngay</a>), extra: "dropped" }.to_json)

    assert_equal "“Đặt lịch ngay”", "“#{pointed.label}”"
    assert_not pointed.data.key?("extra")
    assert_includes pointed.to_prompt, "page / in the preview"
    assert_includes pointed.to_prompt, "CSS selector: main > section:nth-of-type(2) > a.btn"
    assert_includes pointed.to_prompt, %(<a class="btn" href="/dat-lich/new">)
  end

  test "ignores anything else" do
    assert_nil PointedElement.from_param("")
    assert_nil PointedElement.from_param("not json")
    assert_nil PointedElement.from_param([ 1 ].to_json)
    assert_nil PointedElement.from_param({ page: "/" }.to_json)
  end

  test "an element without text is shown by its kind" do
    assert_equal "<img>", PointedElement.new("tag" => "img", "text" => "").label
  end
end
