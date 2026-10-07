module ApplicationCable
  # Anyone may connect, so pages on the customers' site can update live too: what a page may
  # listen to is decided by the signed stream names turbo_stream_from puts in it.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_customer

    def connect
      self.current_user = Session.find_by(id: cookies.signed[:admin_session_id])&.user
      self.current_customer = CustomerSession.find_by(id: cookies.signed[:customer_session_id])&.customer
    end
  end
end
