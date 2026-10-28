require "test_helper"

# A Hallmark theme put in place as the storefront's material (bin/theme material <slug>).
class HallmarkMaterialTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir)
    FileUtils.mkdir_p(@root.join(".claude/skills"))
    FileUtils.ln_s(Rails.root.join(".claude/skills/hallmark"), @root.join(".claude/skills/hallmark"))
    FileUtils.mkdir_p(@root.join("app/assets/tailwind"))
    FileUtils.mkdir_p(@root.join("app/views/layouts"))
    FileUtils.cp(Rails.root.join("themes/bold/app/assets/tailwind/theme.css"), @root.join(HallmarkMaterial::THEME_CSS))
  end

  teardown { FileUtils.rm_rf(@root) }

  test "writes the theme's colors as hex, its fonts, the stamp and the layout's width" do
    material = HallmarkMaterial.new(@root, "coral")
    material.apply!
    css = @root.join(HallmarkMaterial::THEME_CSS).read

    assert css.start_with?("/* Hallmark · shape: <the draw's shape> · layout: bold · genre: modern-minimal · theme: Coral")
    assert_match(/--color-canvas: #\h{6};/, css)
    assert_match(/--color-brand-600: #\h{6};/, css)
    assert_includes css, %(--font-display: "General Sans")
    assert_includes css, "--page-width: 1180px;"
    assert_includes css, "--space-md: 16px;"
    assert_not_includes css, "--text-sm:", "Tailwind's text sizes stay Tailwind's"
    assert_not_includes css, "url(", "a storefront has none of a Hallmark page's texture files"
    assert_includes @root.join(HallmarkMaterial::FONTS).read, "api.fontshare.com"
    assert_equal [ "General Sans", "Geist Mono" ], material.families
  end

  test "every Hallmark theme makes a material" do
    HallmarkMaterial.all(@root).each do |slug|
      material = HallmarkMaterial.new(@root, slug)
      assert_match(/\A#\h{6}\z/, material.paper, slug)
      assert material.brand.all? { |color| color.match?(/\A#\h{6}\z/) }, slug
    end
  end

  test "an unknown theme says so" do
    assert_raises(ArgumentError) { HallmarkMaterial.new(@root, "nope") }
  end
end
