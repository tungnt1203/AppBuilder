require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  setup { in_shop }

  test "comes from the shop by name, answers go to the shop, and the order's page is a button" do
    stores(:cats).update!(contact_email: "hello@chubbycats.test")
    order = orders(:pending)
    mail = OrderMailer.confirmation(order)

    assert_equal [ order.email ], mail.to
    assert_equal [ "hello@chubbycats.test" ], mail.reply_to
    assert_equal "#{order.shop.name} <from@example.com>", mail[:from].value
    html = mail.html_part.body.decoded
    assert_match order.shop.name, html
    assert_match(/<a style="display: inline-block;[^"]*" href="#{Regexp.escape(order.storefront_url)}">View your order<\/a>/, html)
    assert_match "Questions? Just reply to this email.", html
  end
end
