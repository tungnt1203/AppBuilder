# Meta's Conversions API without the network: `meta = connect_fake_meta` sets a pixel and an
# access token, and FakeMetaGateway records the events the app sends.
class FakeMetaGateway
  attr_reader :sent
  attr_accessor :error

  def initialize
    @sent = []
  end

  def send_events(pixel_id, events, test_event_code: nil)
    raise error if error
    @sent << { pixel_id:, events:, test_event_code: }
    events.size
  end

  def events = sent.flat_map { |call| call[:events] }
end

module MetaTestHelper
  def connect_fake_meta(gateway = FakeMetaGateway.new)
    MetaGateway.define_singleton_method(:build) { |_token| gateway }
    Store.current.update!(meta_pixel_id: "123456789012345", meta_access_token: "EAAfaketoken1234567890")
    gateway
  end

  def after_teardown
    MetaGateway.define_singleton_method(:build) { |token| new(token) }
    super
  end
end

ActiveSupport.on_load(:active_support_test_case) { include MetaTestHelper }
