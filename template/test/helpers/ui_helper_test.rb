require "test_helper"

class UiHelperTest < ActionView::TestCase
  test "buttons expose variant and size" do
    assert_includes button_classes, "bg-brand-600"
    assert_includes button_classes(:secondary, size: :sm), "text-xs"
    assert_includes button_classes(:ghost), "hover:bg-surface-muted"
  end

  test "unknown button variant or size is rejected" do
    assert_raises(KeyError) { button_classes(:huge) }
    assert_raises(KeyError) { button_classes(:primary, size: :xl) }
  end

  test "badges and alerts use the known tones" do
    assert_includes badge("New", tone: :brand), "New"
    assert_includes alert("Saved", tone: :success), "Saved"
    assert_raises(KeyError) { badge("New", tone: :purple) }
    assert_raises(KeyError) { alert("Saved", tone: :purple) }
  end

  test "avatar uses initials" do
    render inline: "<%= avatar 'Ada Lovelace' %>"

    assert_select "span", text: "AL"
  end
end
