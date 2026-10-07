require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    assert_equal "shopper@example.com", Customer.new(email_address: " Shopper@Example.COM ").email_address
  end

  test "needs a name, a valid unique email and a password of 8 or more" do
    customer = Customer.new(name: "", email_address: "casey@example.com", password: "short")

    assert_not customer.valid?
    assert customer.errors.include?(:name)
    assert customer.errors.include?(:email_address)
    assert customer.errors.include?(:password)
  end

  test "a customer and a staff member may share an email address" do
    assert Customer.new(name: "Owner as shopper", email_address: users(:owner).email_address, password: "longenough").valid?
  end
end
