require "test_helper"

class ToursControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "the tour starts by itself until it has been seen once" do
    get project_path(projects(:shop))
    assert_select "[data-tour-auto-value=true]"
    assert_equal (1..8).map(&:to_s), css_select("[data-tour-step]").map { |stop| stop["data-tour-step"] }.sort_by(&:to_i), "each stop once, in order"
    assert_select "[data-tour-step='5'][data-tour-title='Try on a look']"
    assert_select "[data-tour-step='7'][data-tour-title='See it on your phone']"

    post tour_path
    assert_response :no_content
    seen = users(:owner).reload.toured_at
    assert seen

    get project_path(projects(:shop))
    assert_select "[data-tour-auto-value=false]"

    travel 1.day do
      post tour_path
      assert_equal seen, users(:owner).reload.toured_at
    end
  end
end
