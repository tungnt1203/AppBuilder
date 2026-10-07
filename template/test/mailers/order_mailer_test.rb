require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  test "confirmation lists the order, how to pay and the order's link" do
    mail = OrderMailer.confirmation(orders(:pending))

    assert_equal [ "pat@example.com" ], mail.to
    assert_equal [ "hello@example.com" ], mail.reply_to
    assert_match "#1001", mail.subject
    assert_match "Cat Mom Tee", mail.html_part.body.to_s
    assert_match "bank transfer", mail.text_part.body.to_s
    assert_match "/orders/#{orders(:pending).token}", mail.text_part.body.to_s
  end

  test "shipped has the tracking" do
    mail = OrderMailer.shipped(orders(:shipped))
    assert_match "9400100000000000000000", mail.text_part.body.to_s
  end

  test "the owner and admins hear about new orders" do
    mail = Admin::OrderMailer.placed(orders(:pending))

    assert_equal [ users(:owner).email_address, users(:admin).email_address ].sort, mail.to.sort
    assert_match "$29.00", mail.subject
  end
end
