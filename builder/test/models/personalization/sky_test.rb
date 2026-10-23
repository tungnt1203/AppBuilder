require "test_helper"

class Personalization::SkyTest < ActiveSupport::TestCase
  test "the pole star stands as high as the city is north, and the time is the city's own" do
    sky = Personalization::Sky.for("2020-02-14T21:30", "hanoi-vietnam")
    x, y = sky.send(:project, 37.95, 89.26)
    altitude = 90 - 2 * Math.atan(Math.hypot(x, y)) * 180 / Math::PI
    assert_in_delta 21.03, altitude, 1.0
    assert_in_delta 0, x, 0.02, "due north"
    assert_operator y, :<, 0

    assert_equal Time.utc(2020, 2, 14, 14, 30), sky.instance_variable_get(:@time)
    assert_equal Time.utc(2020, 7, 4, 2), Personalization::Sky.for("2020-07-03", "new-york-ny-usa").instance_variable_get(:@time), "22:00 in summer time"
    assert_nil Personalization::Sky.for("2020-02-30", "hanoi-vietnam")
    assert_nil Personalization::Sky.for("2020-02-14", "atlantis")
  end

  test "only the stars and lines above the horizon, in a disc of the sky's color" do
    sky = Personalization::Sky.for("2020-02-14T21:30", "hanoi-vietnam")
    assert sky.stars.all? { |x, y, _| Math.hypot(x, y) <= 1 }
    assert_operator sky.stars.size, :<, Personalization::Sky.data["stars"].size

    svg = sky.svg(400, sky: "#0b1d3a", ink: "#ffffff", lines: false)
    assert_includes svg, %(fill="#0b1d3a")
    assert_not_includes svg, "<path"
  end
end
