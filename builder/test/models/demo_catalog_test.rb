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

  NICHE = {
    "products" => %w[ tee sale_tee hoodie sweatshirt mug poster tote ].to_h { |role| [ role, { "title" => "Reel #{role.humanize}", "phrase" => "Reel cool dad", "description" => "Printed to order." } ] }
      .merge("stickers" => { "title" => "Bait Stickers", "phrases" => [ "Fish on", "Catch and release", "Dad" ], "description" => "Three vinyl stickers." }),
    "collections" => [ "Lake Layers", "Father's Day Catch", "Dad Joke Dock" ], "accent" => "#2f6f8f"
  }.freeze

  test "a shop's niche makes the demo products its own kind, with its words drawn on their photos" do
    skip "needs rsvg-convert" unless system("which rsvg-convert", out: File::NULL)

    assert_equal 8, DemoCatalog.add!(niche: NICHE)
    tee = Product.find_by!(title: "Reel Tee")
    assert_equal "Printed to order.", tee.description
    assert_equal %w[ classic-tee-black.jpg classic-tee-white.jpg classic-tee-navy.jpg ], tee.images.map { |image| image.filename.to_s }
    assert_equal [ 1200, 1413 ], tee.images.first.blob.analyze.then { tee.images.first.blob.metadata.values_at("width", "height") }
    assert_equal 2, tee.buyer_inputs.sole.dig("preview", "images").size, "the name still goes on the dark photos"
    assert_equal [ "Dad Joke Dock", "Father's Day Catch", "Lake Layers" ], Collection.where(demo: true).pluck(:title).sort
  end

  test "Claude's reply becomes a niche only when every product and three collections are in it" do
    niche = DemoCatalog::Niche.new("Fishing tees")
    reply = JSON.generate(NICHE.merge("accent" => "teal", "extra" => "ignored"))
    niche.define_singleton_method(:ask) { "Here you go:\n#{reply}" }
    assert_equal "#d9643a", niche.spec["accent"], "a color that isn't hex falls back"
    assert_equal "Reel cool dad", niche.spec.dig("products", "mug", "phrase")

    incomplete = DemoCatalog::Niche.new("Fishing tees")
    incomplete.define_singleton_method(:ask) { JSON.generate(NICHE.merge("collections" => [ "Only one" ])) }
    assert_nil incomplete.spec
  end
end
