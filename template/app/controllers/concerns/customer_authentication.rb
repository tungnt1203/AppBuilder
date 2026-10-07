# Sign in for customers on the customers' site, when the app has customer accounts
# (config.x.customer_accounts). Pages are public unless a controller asks for a customer with
# `before_action :require_customer`. Separate from the owner's and staff's sign in
# to /admin (Admin::Authentication): its own cookie, its own screens.
module CustomerAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :customer_accounts?, :customer_signed_in?
  end

  private
    def customer_accounts?
      Rails.configuration.x.customer_accounts
    end

    # For the account screens themselves: they don't exist while the app has no customer accounts.
    def require_customer_accounts
      head :not_found unless customer_accounts?
    end

    def customer_signed_in?
      customer_accounts? && resume_customer_session.present?
    end

    def require_customer
      require_customer_accounts
      resume_customer_session || request_customer_sign_in unless performed?
    end

    def resume_customer_session
      Current.customer_session ||= find_customer_session_by_cookie
    end

    def find_customer_session_by_cookie
      CustomerSession.find_by(id: cookies.signed[:customer_session_id]) if cookies.signed[:customer_session_id]
    end

    def request_customer_sign_in
      session[:return_to_after_customer_sign_in] = request.url
      redirect_to new_session_path
    end

    def after_customer_sign_in_url
      session.delete(:return_to_after_customer_sign_in) || account_url
    end

    def start_customer_session_for(customer)
      customer.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |customer_session|
        Current.customer_session = customer_session
        cookies.signed.permanent[:customer_session_id] = { value: customer_session.id, httponly: true, same_site: :lax }
      end
    end

    def end_customer_session
      Current.customer_session&.destroy
      cookies.delete(:customer_session_id)
    end
end
