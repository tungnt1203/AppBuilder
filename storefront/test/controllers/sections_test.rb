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

  test "every header keeps the logo, the collections, search, the cart and the phone menu; every footer the policies and help" do
    get blocks_path(only: "chrome")
    assert_response :success

    BlocksController::CHROME["headers"].each do |variant|
      assert_select "[data-header=#{variant}]", 1, variant do
        assert_select "a[href='/']", minimum: 1
        assert_select "a[href='/collections/cats']", minimum: 2 # the links and the phone menu
        assert_select "a#cart-link[href='/cart']"
        assert_select "[data-controller=menu] button[aria-expanded]", minimum: 1
        assert_select "form[action='/products'], a[href='/products'][role=button]", minimum: 1
      end
    end
    BlocksController::CHROME["footers"].each do |variant|
      assert_select "[data-footer=#{variant}]", 1, variant do
        assert_select "a[href=?]", "/policies/refund"
        assert_select "a[href=?]", "/contact"
        assert_select "a[href=?]", "/orders/find"
      end
    end
  end
end
