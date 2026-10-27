require "test_helper"

class ShopAdmin::ClipartSetsControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_staff) }

  test "makes a set with its first pictures" do
    post shop_admin_clipart_sets_path, params: { clipart_set: { name: " Zodiac  signs ", pictures: [ picture("Leo.png"), picture("Leo.txt", "text/plain") ] } }

    set = ClipartSet.find_by!(name: "Zodiac signs")
    assert_redirected_to edit_shop_admin_clipart_set_path(set)
    assert_equal [ "Leo.png" ], set.pictures.map { |picture| picture.filename.to_s }
  end

  test "lists sets with their pictures" do
    set = make_set

    get shop_admin_clipart_sets_path

    assert_select "a[href=?]", edit_shop_admin_clipart_set_path(set), text: /Zodiac signs/
    assert_select "a[href=?] img", edit_shop_admin_clipart_set_path(set), 1
  end

  test "adds, renames and removes pictures" do
    set = make_set

    post shop_admin_clipart_set_pictures_path(set), params: { pictures: [ picture("Virgo.png") ] }
    assert_equal 2, set.pictures.reload.count
    assert_equal "1 picture added.", flash[:notice]

    leo = set.pictures.find { |picture| picture.filename.base == "Leo" }
    patch shop_admin_clipart_set_picture_path(set, leo), params: { picture: { name: "The Lion" } }
    assert_equal "The Lion", leo.blob.reload.filename.base

    delete shop_admin_clipart_set_picture_path(set, leo)
    assert_equal [ "Virgo" ], set.pictures.reload.map { |picture| picture.filename.base }
  end

  test "the edit page shows the set's pictures and the products that offer it" do
    set = make_set
    products(:tee).update!(buyer_inputs: [ { "label" => "Your sign", "kind" => "choice", "set" => set.id } ])

    get edit_shop_admin_clipart_set_path(set)

    assert_select "input[name='picture[name]'][value=Leo]"
    assert_select "a[href^=?]", edit_shop_admin_product_path(products(:tee)), text: products(:tee).title
  end

  test "a product's choice field picks a set" do
    set = make_set
    tee = products(:tee)

    patch shop_admin_product_path(tee), params: { product: { title: tee.title, buyer_inputs: [ { label: "Your sign", kind: "choice", set: set.id } ] } }

    assert_equal [ set.id, set.pictures.map(&:id) ], tee.reload.buyer_inputs.sole.values_at("set", "options")
    get edit_shop_admin_product_path(tee)
    assert_select "select[name='product[buyer_inputs][][set]'] option[selected][value=?]", set.id.to_s
  end

  test "deletes a set" do
    set = make_set

    delete shop_admin_clipart_set_path(set)

    assert_redirected_to shop_admin_clipart_sets_path
    assert_not ClipartSet.exists?(set.id)
  end

  private
    def make_set
      ClipartSet.create!(name: "Zodiac signs").tap { |set| set.add_pictures([ picture("Leo.png") ]) }
    end

    def picture(name, type = "image/png")
      Rack::Test::UploadedFile.new(file_fixture("product.png"), type, original_filename: name)
    end
end
