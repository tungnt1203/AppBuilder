require "test_helper"

class Cart::CleanupJobTest < ActiveJob::TestCase
  setup { in_shop }

  test "a buyer's photo goes once no cart or order has it and it's a month old; one on an order stays" do
    photo = -> { BuyerUpload.take(Rack::Test::UploadedFile.new(file_fixture("product.png"), "image/png")) }
    bought, in_cart, unused, recent = 4.times.map { photo.call }
    [ bought, in_cart, unused ].each { |upload| upload.update!(created_at: 40.days.ago) }
    line_items(:pending_tee).update!(properties: { "photo" => bought.token, "photo_crop" => "1,0.5,0.5" })
    Cart.create!.items.create!(variant: variants(:tee_black_s), quantity: 1, properties: { "photo" => in_cart.token })

    perform_enqueued_jobs { Cart::CleanupJob.perform_now }
    assert_equal [ bought, in_cart, recent ].map(&:id).sort, BuyerUpload.pluck(:id).sort
    assert_not ActiveStorage::Attachment.exists?(record_type: "BuyerUpload", record_id: unused.id)
  end
end
