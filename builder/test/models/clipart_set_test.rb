require "test_helper"

class ClipartSetTest < ActiveSupport::TestCase
  setup do
    in_shop
    @set = ClipartSet.create!(name: "Zodiac signs")
    @set.add_pictures([ picture("Leo.png"), picture("Virgo.png") ])
  end

  test "a choice field offering a set offers every picture in it, in order" do
    product = offer(@set)

    assert_equal @set.pictures.attachments.sort_by(&:id).map(&:id), product.buyer_inputs.sole["options"]
    assert_equal [ "Leo", "Virgo" ], product.choice_pictures.values.map { |picture| picture.filename.base }
  end

  test "products follow the set as pictures are added, renamed and taken out" do
    product = offer(@set)

    @set.add_pictures([ picture("Aries.png") ])
    assert_equal 3, product.reload.buyer_inputs.sole["options"].size

    leo = @set.pictures.find { |picture| picture.filename.base == "Leo" }
    @set.rename_picture(leo, "  The Lion ")
    assert_equal "The Lion.png", leo.reload.filename.to_s

    @set.remove_picture(leo)
    assert_not_includes product.reload.buyer_inputs.sole["options"], leo.id
  end

  test "a buyer's pick from the set is accepted, named and shown on their line" do
    product = offer(@set)
    virgo = @set.pictures.find { |picture| picture.filename.base == "Virgo" }

    properties, errors = BuyerInputs.accept(product.buyer_inputs, "your_sign" => virgo.id.to_s)
    assert_nil errors

    item = LineItem.new(product_title: product.title, variant: product.variants.first, properties:)
    assert_equal [ "Your sign: Virgo" ], item.property_lines
  end

  test "a deleted set leaves its products offering nothing, not a set that's gone" do
    product = offer(@set)

    @set.destroy!

    field = product.reload.buyer_inputs.sole
    assert_nil field["set"]
    assert_empty field["options"]
  end

  test "only images go in, up to the most a buyer picks from" do
    assert_equal 0, @set.add_pictures([ Rack::Test::UploadedFile.new(file_fixture("product.png"), "text/plain") ])
    assert_equal ClipartSet::MAX_PICTURES - 2, @set.room
  end

  test "a set from another shop isn't offered" do
    other = ActsAsTenant.with_tenant(shops(:dogs)) { ClipartSet.create!(name: "Breeds") }
    product = products(:tee)
    product.update!(buyer_inputs: [ { "label" => "Your sign", "kind" => "choice", "set" => other.id } ])

    assert_nil product.buyer_inputs.sole["set"]
  end

  private
    def picture(name)
      Rack::Test::UploadedFile.new(file_fixture("product.png"), "image/png", original_filename: name)
    end

    def offer(set)
      products(:tee).tap { |tee| tee.update!(buyer_inputs: [ { "label" => "Your sign", "kind" => "choice", "set" => set.id.to_s } ]) }
    end
end
