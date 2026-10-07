module SessionTestHelper
  # Signs in an owner or staff member (User) to /admin.
  def sign_in_as(user)
    Current.session = user.sessions.create!
    set_signed_cookie :admin_session_id, Current.session.id
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("admin_session_id")
  end

  # Signs in a customer to the customers' site.
  def sign_in_as_customer(customer)
    Current.customer_session = customer.sessions.create!
    set_signed_cookie :customer_session_id, Current.customer_session.id
  end

  private
    def set_signed_cookie(name, value)
      ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
        cookie_jar.signed[name] = value
        cookies[name.to_s] = cookie_jar[name]
      end
    end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
