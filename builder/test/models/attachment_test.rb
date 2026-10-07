require "test_helper"

class AttachmentTest < ActiveSupport::TestCase
  test "keeps file names readable and safe" do
    assert_equal "Thực đơn quán.pdf", Attachment.safe_name("Thực đơn quán.pdf")
    assert_equal "passwd", Attachment.safe_name("../../etc/passwd")
    assert_equal "htaccess", Attachment.safe_name(".htaccess")
    assert_equal "logo_1_.png", Attachment.safe_name("logo<1>.png")
  end

  test "doesn't overwrite a file with the same name" do
    Dir.mktmpdir do |dir|
      folder = Pathname(dir)
      folder.join("logo.png").write("1")

      assert_equal "logo-2.png", Attachment.unique_name(folder, "logo.png")
    end
  end
end
