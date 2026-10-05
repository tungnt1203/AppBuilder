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
end
