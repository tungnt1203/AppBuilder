# Development only, for the builder's preview: keeps the preview private to the people
# the builder lets in. The builder writes a secret to tmp/preview_secret and opens the
# preview through /_preview/enter with a short-lived ticket signed with it; that sets a
# cookie good for this preview. The builder's own checks and bin/look send the pass in
# the X-Preview-Pass header or that cookie. Without tmp/preview_secret (the app run
# outside the builder) it lets everyone in. Never runs in production. Don't change or
# remove it.
if Rails.env.development?
  require "openssl"

  class PreviewGate
    ENTER = "/_preview/enter"
    OPEN = [ "/up" ].freeze
    SECRET = Rails.root.join("tmp/preview_secret")

    def self.pass(secret)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "preview-pass")
    end

    def self.cookie_name(secret)
      "_preview_#{pass(secret).first(12)}"
    end

    def self.ticket_valid?(secret, ticket)
      expires, signature = ticket.to_s.split("--", 2)
      return false unless expires.to_i > Time.now.to_i && signature

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "enter:#{expires.to_i}")
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      secret = SECRET.read.strip if SECRET.exist?
      return @app.call(env) if secret.blank? || OPEN.include?(env["PATH_INFO"])

      request = Rack::Request.new(env)
      return enter(request, secret) if request.path == ENTER

      given = env["HTTP_X_PREVIEW_PASS"].presence || request.cookies[self.class.cookie_name(secret)]
      return @app.call(env) if given && ActiveSupport::SecurityUtils.secure_compare(self.class.pass(secret), given)

      closed
    end

    private
      def enter(request, secret)
        return closed unless self.class.ticket_valid?(secret, request.params["ticket"])

        response = Rack::Response.new([], 303, "location" => "/", "cache-control" => "no-store")
        response.set_cookie(self.class.cookie_name(secret), value: self.class.pass(secret), path: "/", httponly: true, same_site: :lax)
        response.finish
      end

      def closed
        page = <<~HTML
          <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Private preview</title></head>
          <body style="font-family:system-ui,sans-serif;display:grid;place-items:center;min-height:90vh;color:#334;text-align:center">
          <div><h1 style="font-size:1.25rem">This preview is private</h1><p>Open it from the studio.</p></div></body></html>
        HTML
        [ 403, { "content-type" => "text/html; charset=utf-8", "cache-control" => "no-store" }, [ page ] ]
      end
  end

  Rails.application.config.middleware.insert_before 0, PreviewGate
end
