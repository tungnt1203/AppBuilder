require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "gets a fixed id of its own, not taken from its name, and the next free preview port" do
    project = Project.create!(name: "Trung tâm Anh ngữ", language: "vi")

    assert_match(/\A[a-z0-9]{8}\z/, project.slug)
    assert_equal 4003, project.port
    assert project.setting_up?
    assert_equal Rails.configuration.x.projects_root.join(project.slug), project.path
    assert_equal "http://localhost:4003", project.preview_url
  end

  test "is published at a subdomain from its name, kept from the first publish on" do
    project = Project.create!(name: "Trung tâm Anh ngữ", language: "vi")
    assert_equal "trung-tam-anh-ngu.localhost", project.publish_host
    assert_nil project.subdomain

    project.publish
    project.update!(name: "Anh ngữ Mai")

    assert_equal "trung-tam-anh-ngu", project.subdomain
    assert_equal "trung-tam-anh-ngu.localhost", project.publish_host
  end

  test "subdomains stay unique" do
    project = Project.create!(name: "Shop", language: "en")

    assert_match(/\Ashop-\h{4}\.localhost\z/, project.publish_host)
  end

  test "only known languages" do
    assert_not Project.new(name: "X", language: "fr").valid?
    assert_equal "duong-pho.localhost", Project.create!(name: "Đường phố", language: "vi").publish_host
    assert_equal "Asia/Ho_Chi_Minh", projects(:clinic).time_zone
  end

  test "a reply stays open until the owner answers it" do
    project = projects(:clinic)
    reply = project.messages.create!(role: :assistant, body: "Câu hỏi?", data: { "questions" => [] })
    project.messages.create!(role: :result)
    assert_equal reply, project.open_reply

    project.messages.create!(role: :user, body: "Trả lời")
    assert_nil project.open_reply
  end

  test "accepts messages when not busy" do
    assert projects(:clinic).accepts_messages?
    assert_not projects(:shop).accepts_messages?
  end

  test "adopting a suggested name leaves the app's address alone" do
    project = Project.new(language: "vi")
    project.name_after("Quản lý hội viên phòng gym quận 3")
    project.save!
    slug = project.slug

    project.adopt_name("Gym Quận 3")

    assert_equal [ "Gym Quận 3", slug ], [ project.name, project.slug ]
    assert_not project.name_pending?
  end

  test "keeps the provisional name when none was suggested" do
    project = Project.new(language: "vi")
    project.name_after("Quản lý hội viên phòng gym quận 3")
    project.save!

    project.adopt_name(nil)

    assert_equal "Quản lý hội viên", project.name
  end
end
