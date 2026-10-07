require "test_helper"

class Admin::CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:staff) }

  test "lists collections" do
    get admin_collections_path
    assert_select "a[href=?]", edit_admin_collection_path(collections(:cats))
  end

  test "adds a collection with products" do
    post admin_collections_path, params: { collection: { title: "Gifts", product_ids: [ "", products(:mug).id ] } }

    collection = Collection.find_by!(title: "Gifts")
    assert_equal "gifts", collection.slug
    assert_equal [ products(:mug) ], collection.products.to_a
  end

  test "changes the products" do
    patch admin_collection_path(collections(:cats)), params: { collection: { title: "Cat Lovers", product_ids: [ "", products(:mug).id ] } }
    assert_equal [ products(:mug) ], collections(:cats).reload.products.to_a
  end

  test "deletes" do
    delete admin_collection_path(collections(:cats))
    assert_not Collection.exists?(collections(:cats).id)
    assert Product.exists?(products(:tee).id)
  end
end
