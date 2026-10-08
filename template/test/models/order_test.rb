require "test_helper"

class OrderTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "moves forward and records each step with who did it" do
    order = orders(:pending)

    order.mark_paid!(by: users(:owner), reference: "TX-42")
    order.start_production!(by: users(:staff))
    order.ship!(carrier: "USPS", tracking_number: "9400 1", tracking_url: "https://tools.usps.com/x", by: users(:staff))
    order.mark_delivered!

    assert order.delivered?
    assert_equal "TX-42", order.payment_reference
    assert order.paid_at && order.shipped_at && order.delivered_at
    assert_equal %w[ placed paid in_production shipped delivered ], order.events.map(&:action)
    assert_equal users(:staff), order.events.find_by(action: "shipped").user
  end

  test "shipping emails the buyer" do
    assert_enqueued_email_with OrderMailer, :shipped, args: [ orders(:paid) ] do
      orders(:paid).ship!(carrier: "UPS", tracking_number: "1Z")
    end
  end

  test "can't skip or go back" do
    assert_raises(Order::InvalidTransition) { orders(:pending).ship!(carrier: "UPS", tracking_number: "1Z") }
    assert_raises(Order::InvalidTransition) { orders(:shipped).mark_paid! }
    assert_raises(Order::InvalidTransition) { orders(:shipped).cancel! }
    assert orders(:pending).reload.pending?
  end

  test "cancelling and refunding" do
    orders(:pending).cancel!(reason: "Duplicate")
    assert orders(:pending).cancelled?
    assert_equal "Duplicate", orders(:pending).events.last.message

    orders(:shipped).refund!
    assert orders(:shipped).refunded?
  end

  test "the buyer hears when their order is cancelled or refunded" do
    assert_enqueued_email_with OrderMailer, :cancelled, args: [ orders(:pending) ] do
      orders(:pending).cancel!
    end
    assert_enqueued_email_with OrderMailer, :refunded, args: [ orders(:shipped) ] do
      orders(:shipped).refund!
    end
    assert_no_enqueued_emails { orders(:paid).cancel!(notify: false) }
  end

  test "a tracking link must be a web address" do
    assert_raises(ActiveRecord::RecordInvalid) { orders(:paid).ship!(carrier: "UPS", tracking_number: "1", tracking_url: "javascript:alert(1)") }
    assert orders(:paid).reload.paid?
  end

  test "reached by its token, not its id" do
    assert_equal orders(:paid).token, orders(:paid).to_param
    assert_operator orders(:paid).token.length, :>=, 24
  end

  test "search by number, email or name" do
    assert_equal [ orders(:paid) ], Order.search("#1002").to_a
    assert_equal [ orders(:paid) ], Order.search("lee@").to_a
    assert_equal [ orders(:shipped) ], Order.search("Sam Buy").to_a
  end
end
