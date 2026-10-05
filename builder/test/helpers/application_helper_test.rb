require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "markdown renders lists that follow a line without a blank line" do
    html = markdown("**Lịch hẹn**\n- Xem lịch hôm nay\n- Đặt lịch mới")

    assert_includes html, "<li>Xem lịch hôm nay</li>"
    assert_includes html, "<strong>Lịch hẹn</strong>"
  end

  test "markdown drops raw HTML from replies" do
    assert_not_includes markdown("<script>alert(1)</script>"), "<script>"
  end

  test "steps summary says how long it thought and what it touched" do
    actions = [
      Message.new(role: :action, data: { "tool" => "Thinking", "seconds" => 5 }),
      Message.new(role: :action, data: { "tool" => "Read" }),
      Message.new(role: :action, data: { "tool" => "Edit" }),
      Message.new(role: :action, data: { "tool" => "Bash" })
    ]

    assert_equal "Thought for 5 seconds, looked at 1 file, changed 1 file, and ran 1 command", steps_summary(actions)
  end
end
