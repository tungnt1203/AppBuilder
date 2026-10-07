require "test_helper"

# The page blocks are copied into apps' pages (design skill), so each must render on its own.
class BlocksTest < ActionView::TestCase
  helper UiHelper

  Rails.root.glob("app/views/blocks/_*.html.erb").each do |file|
    block = file.basename.to_s.delete_prefix("_").delete_suffix(".html.erb")

    test "#{block} renders" do
      render partial: "blocks/#{block}"
      assert_operator rendered.length, :>, 200
    end
  end
end
