require "test_helper"

# The sections a home page is composed from (app/views/sections), each in every variant, with the
# shop's real products and collections.
class SectionsTest < ActionDispatch::IntegrationTest
  setup do
    @platform.products_data.first["buyer_inputs"] = [ { "key" => "print_name", "label" => "Name on the shirt", "required" => false, "max_length" => 20 } ]
  end

  test "every variant of every section shows the shop's products and collections" do
    get blocks_path(only: "sections")
    assert_response :success

    BlocksController::SECTIONS.each do |section, variants|
      variants.each do |variant|
        assert_select "[data-section=#{section}][data-variant=#{variant}]", { minimum: 1 }, "#{section} #{variant}" unless section == "personalized" && variant == "split"
      end
    end
    assert_select "[data-section=products] a[href='/products/cat-tee']", minimum: 4
    assert_select "[data-section=collections] a[href='/collections/cats']", count: 4
    assert_select "[data-section=personalized] a[href='/products/cat-tee']", minimum: 2
  end
end
