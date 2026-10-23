require "test_helper"

class DemoCatalogTest < ActiveSupport::TestCase
  setup { in_shop }

  test "adds sample products with photos, options and costs once, and removes only them" do
    own = products(:tee)

    assert_difference -> { Product.count }, 8 do
      assert_equal 8, DemoCatalog.add!
      DemoCatalog.add! # once
    end
    tee = Product.find_by!(title: "Good Things Tee")
    assert tee.demo? && tee.active?
    assert_equal 3, tee.images.count
    assert_equal "classic-tee-white.jpg", tee.image_for(tee.variant_for(%w[ White S ])).filename.to_s
    assert_empty tee.launch_problems
    assert Product.find_by!(title: "Stay Golden Tee").variants.all?(&:on_sale?)
    assert_equal [ "text", 2 ], [ tee.buyer_inputs.sole["kind"], tee.buyer_inputs.sole.dig("preview", "images").size ], "a name on its dark photos"
    assert_equal "photo", Product.find_by!(title: "But First, Coffee Mug").buyer_inputs.sole["kind"]
    assert_equal "Dancing Script", Product.find_by!(title: "Wander Poster").buyer_inputs.sole.dig("preview", "font")
    assert_equal 3, Collection.where(demo: true).count

    assert_equal 8, DemoCatalog.remove!
    assert_not DemoCatalog.present?
    assert Product.exists?(own.id), "the owner's products stay"
    assert_equal 0, Collection.where(demo: true).count
  end
end
