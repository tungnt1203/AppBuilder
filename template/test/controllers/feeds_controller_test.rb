require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  test "the product feed lists each variant on sale, with the ids the pixels send" do
    variants(:tee_black_m).update!(sku: nil)

    get products_feed_path
    assert_response :success
    feed = Nokogiri::XML(response.body)
    ids = feed.xpath("//item/g:id", "g" => "http://base.google.com/ns/1.0").map(&:text)

    assert_includes ids, "TEE-BLK-S"
    assert_includes ids, "variant-#{variants(:tee_black_m).id}"
    assert_not_includes ids, variants(:hoodie).catalog_id, "drafts aren't in it"

    black_m = feed.xpath("//item[g:id='variant-#{variants(:tee_black_m).id}']", "g" => "http://base.google.com/ns/1.0").first
    value = ->(name) { black_m.at_xpath("g:#{name}", "g" => "http://base.google.com/ns/1.0")&.text }
    assert_equal [ "30.00 USD", "24.00 USD", "Black", "M", "in_stock" ], %w[ price sale_price color size availability ].map(&value)
    assert_includes value.("link"), "options%5B%5D=Black"
    assert_equal "out_of_stock", feed.at_xpath("//item[g:id='#{variants(:tee_white_s).catalog_id}']/g:availability", "g" => "http://base.google.com/ns/1.0").text
  end

  test "the feed's link opens the product with that variant picked" do
    get product_path(products(:tee), options: %w[ White M ])
    assert_select "input[name=variant_id][value=?]", variants(:tee_white_m).id.to_s
  end
end
