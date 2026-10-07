require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "lists active products for any visitor, even with no accounts" do
    User.delete_all
    get products_path

    assert_response :success
    assert_select "a[href=?]", product_path(products(:tee))
    assert_select "a[href=?]", product_path(products(:hoodie)), count: 0
  end

  test "search and sort" do
    get products_path(q: "mug", sort: "title")
    assert_select "a[href=?]", product_path(products(:mug))
    assert_select "a[href=?]", product_path(products(:tee)), count: 0
  end

  test "shows a product by its address, with its options and add to cart" do
    get product_path(products(:tee))

    assert_response :success
    assert_select "h1", "Cat Mom Tee"
    assert_select "input[type=radio][value=Black]"
    assert_select "input[name=variant_id][value=?]", variants(:tee_black_s).id.to_s
  end

  test "drafts aren't on the site" do
    get product_path(products(:hoodie))
    assert_response :not_found
  end

  test "home page shows the newest products and collections" do
    get root_path
    assert_select "a[href=?]", product_path(products(:mug))
    assert_select "a[href=?]", collection_path(collections(:cats))
  end

  test "collection page shows its active products" do
    get collection_path(collections(:cats))
    assert_response :success
    assert_select "a[href=?]", product_path(products(:tee))
    assert_select "a[href=?]", product_path(products(:hoodie)), count: 0
  end
end
