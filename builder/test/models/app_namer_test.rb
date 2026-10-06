require "test_helper"

class AppNamerTest < ActiveSupport::TestCase
  test "asks for a name in the app's language, without tools or settings" do
    namer = AppNamer.new("Quản lý hội viên", language: "vi")

    assert_includes namer.prompt, "Tiếng Việt có dấu"
    assert_includes namer.prompt, "Quản lý hội viên"
    assert_equal [ "--model", "sonnet" ], namer.command.values_at(3, 4)
    assert_includes namer.command.join(" "), "--tools "
  end

  test "keeps only a short clean name" do
    namer = AppNamer.new("x", language: "en")

    replies = [ "\n“Gym Hub”.\n", "Here is a name you could use for your fitness app idea today" ]
    namer.define_singleton_method(:ask) { replies.shift or raise ProjectShell::Error, "claude failed" }

    assert_equal "Gym Hub", namer.name
    assert_nil namer.name
    assert_nil namer.name
  end
end
