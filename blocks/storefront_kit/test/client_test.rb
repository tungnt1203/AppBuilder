require_relative "test_helper"

class ClientTest < Minitest::Test
  def setup
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  def client(transport) = StorefrontKit::Client.new(url: "https://platform.example/", key: "sk_shop_1", cache: @cache, transport:)

  def test_sends_the_key_and_answers_the_json
    transport = FakeTransport.new([ 200, { "shop" => { "name" => "Cats" } } ])
    assert_equal({ "shop" => { "name" => "Cats" } }, client(transport).get("shop"))

    uri, request = transport.requests.sole
    assert_equal "https://platform.example/v1/shop", uri.to_s
    assert_equal "Bearer sk_shop_1", request["Authorization"]
  end

  def test_a_304_takes_the_cached_body_and_an_outage_too
    transport = FakeTransport.new([ 200, { "n" => 1 }, { "ETag" => "W/\"a\"" } ], [ 304, nil ], Errno::ECONNREFUSED)
    client = client(transport)

    assert_equal({ "n" => 1 }, client.get("products", { page: 2 }))
    assert_equal({ "n" => 1 }, client.get("products", { page: 2 }))
    assert_equal "W/\"a\"", transport.requests.last.last["If-None-Match"]
    assert_equal({ "n" => 1 }, client.get("products", { page: 2 })) # the Platform is down
    assert_equal "https://platform.example/v1/products?page=2", transport.requests.first.first.to_s
  end

  def test_fresh_reads_skip_the_request
    transport = FakeTransport.new([ 200, { "n" => 1 } ])
    client = client(transport)
    client.get("shop", fresh_for: 30)
    assert_equal({ "n" => 1 }, client.get("shop", fresh_for: 30))
    assert_equal 1, transport.requests.size
  end

  def test_errors_come_as_their_class_with_the_fields
    transport = FakeTransport.new([ 422, { "error" => { "code" => "invalid", "message" => "Some details need fixing", "fields" => { "email" => "is invalid" } } } ], [ 404, {} ])
    client = client(transport)

    error = assert_raises(StorefrontKit::Invalid) { client.post("checkouts", { email: "x" }, idempotency_key: "k1") }
    assert_equal [ "invalid", { "email" => "is invalid" }, 422 ], [ error.code, error.fields, error.status ]
    assert_equal "k1", transport.requests.first.last["Idempotency-Key"]
    assert_equal({ email: "x" }.to_json, transport.requests.first.last.body)
    assert_raises(StorefrontKit::NotFound) { client.get("products/nope") }
  end

  def test_unreachable_without_a_cache
    assert_raises(StorefrontKit::Unreachable) { client(FakeTransport.new(Net::OpenTimeout)).post("carts") }
    assert_raises(StorefrontKit::Unreachable) { client(FakeTransport.new([ 503, {} ])).get("shop") }
  end
end
