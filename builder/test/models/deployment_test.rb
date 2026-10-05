require "test_helper"

class DeploymentTest < ActiveSupport::TestCase
  test "numbers versions per project and names the image after them" do
    first = projects(:clinic).deployments.create!
    second = projects(:clinic).deployments.create!

    assert_equal [ 1, 2 ], [ first.version, second.version ]
    assert_equal "localhost:5050/nha-khoa:v2", second.image
    assert second.building?
  end
end
