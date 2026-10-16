require "active_support"
require "active_support/core_ext"
require "minitest/autorun"
require "storefront_kit"
require "storefront_kit/testing"

# A transport that answers from a list of [status, body, headers] and keeps the requests.
class FakeTransport
  Response = Struct.new(:code, :body, :headers) do
    def [](name) = headers.to_h[name]
  end

  attr_reader :requests

  def initialize(*answers)
    @answers, @requests = answers, []
  end

  def call(uri, request)
    @requests << [ uri, request ]
    answer = @answers.shift or raise Errno::ECONNREFUSED
    raise answer if answer.is_a?(Class) || answer.is_a?(Exception)

    status, body, headers = answer
    Response.new(status.to_s, body && JSON.generate(body), headers)
  end
end
