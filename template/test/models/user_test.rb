require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "invite creates a member with an unguessable password" do
    user = User.invite(name: "New Person", email_address: "new@example.com")

    assert user.persisted?
    assert user.member?
    assert_not user.authenticate("password")
  end

  test "requires a name and a valid email address" do
    user = User.new(email_address: "not-an-email", password: "secret")

    assert_not user.valid?
    assert user.errors.include?(:name)
    assert user.errors.include?(:email_address)
  end

  test "administrators are admins and the owner" do
    assert users(:owner).administrator?
    assert users(:admin).administrator?
    assert_not users(:member).administrator?
  end

  test "the owner cannot be demoted or removed" do
    owner = users(:owner)

    assert_not owner.update(role: "member")
    assert_not owner.destroy
    assert User.exists?(owner.id)
  end

  test "invitation token stops working once a password is chosen" do
    user = users(:member)
    token = user.generate_token_for(:invitation)
    assert_equal user, User.find_by_token_for(:invitation, token)

    user.update!(password: "a new password")
    assert_nil User.find_by_token_for(:invitation, token)
  end
end
