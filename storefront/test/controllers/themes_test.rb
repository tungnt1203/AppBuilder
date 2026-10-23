require "test_helper"

# The themes as the template ships them. Once a storefront has its own design (DESIGN.md), its
# files are its own and these checks are the template's, not the shop's.
class ThemesTest < ActionDispatch::IntegrationTest
  THEMES = Rails.root.join("themes").children.select(&:directory?).sort

  setup { skip "this storefront has its own design" unless Rails.root.join("DESIGN.md").read.include?("Not decided yet") }

  test "a new storefront starts with the clean theme in place" do
    each_file(Rails.root.join("themes/clean")) do |file, path|
      assert_equal file.read, Rails.root.join(path).read, "#{path} differs from themes/clean (run bin/theme clean, or change both)"
    end
  end

  test "each theme says what it is and replaces only files the app has" do
    THEMES.each do |theme|
      assert theme.join("README.md").read.match?(/\A# #{theme.basename}\n\n.+\n\nReference: https:/), "#{theme.basename}/README.md starts with its name, a summary and its reference"
      assert theme.join("app/assets/tailwind/theme.css").exist?, "#{theme.basename} has its theme.css"
      each_file(theme) { |_, path| assert Rails.root.join(path).exist?, "#{theme.basename}/#{path} replaces nothing in the app" }
    end
  end

  test "each theme's pages work: home, catalog, a product, a collection, the cart and checkout" do
    THEMES.each do |theme|
      with_views_of(theme) do
        get root_path
        assert_response :success, theme.basename
        assert_select "h1", "Tees for people who love a chubby cat"
        assert_select "header a[href='/collections/cats']", minimum: 1
        assert_select "header a[href=?]", "/pages/about", text: "About"
        assert_select "a[href='/products/cat-tee']", minimum: 1
        assert_select "footer a[href=?]", "/policies/refund"
        assert_select "div", text: "Free shipping over $50"

        get products_path
        assert_select "a[href='/products/cat-tee'] span", "-20%"
        get product_path("cat-tee")
        assert_response :success, theme.basename
        get collection_path("cats")
        assert_response :success, theme.basename

        post cart_items_path, params: { variant_id: 101, quantity: 1 }
        get cart_path
        assert_select "header a#cart-link"
        get new_checkout_path
        assert_select "header nav", count: 0
        assert_select "footer a[href=?]", "/policies/refund"
        assert_select "footer a[href=?]", "/products", count: 0
      end
    end
  end

  private
    # Each file a theme puts in place, with its path in the app.
    def each_file(theme)
      theme.glob("**/*").select(&:file?).reject { |file| file.basename.to_s == "README.md" }.each do |file|
        yield file, file.relative_path_from(theme)
      end
    end

    def with_views_of(theme)
      original = ApplicationController.view_paths
      ApplicationController.prepend_view_path(theme.join("app/views").to_s)
      yield
    ensure
      ApplicationController.view_paths = original
    end
end
