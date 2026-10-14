require "application_system_test_case"

class ProductPageTest < ApplicationSystemTestCase
  test "picking a color shows its photo, and on a phone the button follows the buyer" do
    product = products(:tee)
    %w[ tee-black tee-white tee-back tee-side tee-detail tee-flat ].each { |name| product.images.attach(io: file_fixture("product.png").open, filename: "#{name}.png", content_type: "image/png") }
    product.update!(description: "Soft cotton.\n\n" * 40)

    on_phone do
      visit product_path(product)
      assert_selector "[data-gallery-target=main][src*='tee-black']"
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, 390, "six photos don't make the page wider than the phone"

      find("label[title=White]").click
      assert_selector "[data-gallery-target=main][src*='tee-white']"
      assert_text "Color: White"
      find("label[title=M]").click

      assert_no_selector "[data-sticky-buy-target=bar]", visible: true
      execute_script "window.scrollTo(0, document.body.scrollHeight)"
      within("[data-sticky-buy-target=bar]") { click_on "Add to cart" }
    end

    assert_text "Cat Mom Tee was added to your cart"
    assert_equal variants(:tee_white_m), Cart.last.items.sole.variant
  end
end
