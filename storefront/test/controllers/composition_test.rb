require "test_helper"

# A shop with its own design (DESIGN.md) has a composed home page, not the layout's: its products,
# what buyers personalize and its collections come in the sections (app/views/sections), and at
# most one of them in its first variant (STOREFRONT.md, "Sections to compose with"). The builder
# runs the tests before a turn ends, so a home page left as the layout made it is sent back.
class CompositionTest < ActionDispatch::IntegrationTest
  FIRST_VARIANTS = { "products" => "grid", "personalized" => "split", "collections" => "tiles" }.freeze

  setup do
    skip "the template's own home page (no design decided yet)" if Rails.root.join("DESIGN.md").read.include?("Not decided yet")
    @platform.products_data.first["buyer_inputs"] = [ { "key" => "print_name", "label" => "Name on the shirt", "required" => false, "max_length" => 20 } ]
  end

  test "the home page is composed from the sections, in the draw's variants" do
    get root_path
    assert_response :success

    variants = FIRST_VARIANTS.keys.index_with do |section|
      css_select("[data-section=#{section}]").map { |node| node["data-variant"] }
    end
    # The owner's words outrank the draw: DESIGN.md's "Kept as asked: products" frees a section.
    kept = Rails.root.join("DESIGN.md").read[/^\W*Kept as asked:\W*(.+)$/i, 1].to_s.downcase
    missing = variants.select { |section, found| found.empty? && !kept.include?(section) }.keys
    assert_empty missing, "The home page should show the shop's #{missing.to_sentence} through app/views/sections " \
      "(render \"sections/#{missing.first}\", variant: …), with the variant the draw calls for. See STOREFRONT.md, \"Sections to compose with\"."

    first = variants.select { |section, found| found.include?(FIRST_VARIANTS[section]) && !kept.include?(section) }.keys
    assert first.size <= 1, "#{first.to_sentence} still use their first variant (#{first.map { |section| FIRST_VARIANTS[section] }.to_sentence}), " \
      "as the layout's home page does: pick the variants the draw calls for (feature, rail, index; steps, band; index, bento, row)."
  end
end
