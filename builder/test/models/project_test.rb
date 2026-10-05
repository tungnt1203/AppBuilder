require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "gets a slug from its name and the next free preview port" do
    project = Project.create!(name: "Trung tâm Anh ngữ", language: "vi")

    assert_equal "trung-tam-anh-ngu", project.slug
    assert_equal 4003, project.port
    assert project.setting_up?
    assert_equal Rails.configuration.x.projects_root.join("trung-tam-anh-ngu"), project.path
    assert_equal "http://localhost:4003", project.preview_url
  end

  test "slugs stay unique" do
    project = Project.create!(name: "Shop", language: "en")

    assert_match(/\Ashop-\h{4}\z/, project.slug)
  end

  test "only known languages" do
    assert_not Project.new(name: "X", language: "fr").valid?
    assert_equal "duong-pho", Project.create!(name: "Đường phố", language: "vi").slug
    assert_equal "Asia/Ho_Chi_Minh", projects(:clinic).time_zone
  end

  test "accepts messages when not busy" do
    assert projects(:clinic).accepts_messages?
    assert_not projects(:shop).accepts_messages?
  end
end
