require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  test "arranges exactly the given products, in order" do
    collection = collections(:cats)
    collection.arrange_products([ products(:mug).id, products(:tee).id, "", 999_999 ])

    assert_equal [ products(:mug), products(:tee) ], collection.products.order("collection_products.position").to_a
  end
end
