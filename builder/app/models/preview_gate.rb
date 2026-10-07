require "openssl"

# The builder's side of the template's config/initializers/preview_gate.rb, which keeps a
# preview private: a secret per project in its tmp/preview_secret, short-lived tickets
# that let a browser in (it gets a cookie), and the pass the builder's own requests send.
# Apps made before the gate have no initializer and stay open.
class PreviewGate
  TICKET_TTL = 1.minute
  HEADER = "X-Preview-Pass"

  def initialize(project)
    @project = project
  end

  def guarded?
    @project.path.join("config/initializers/preview_gate.rb").exist?
  end

  # Made once and kept, so restarting the preview doesn't sign everyone out of it.
  def secret
    return secret_path.read.strip if secret_path.exist?

    secret_path.dirname.mkpath
    SecureRandom.hex(32).tap { |value| secret_path.write(value); secret_path.chmod(0o600) }
  end

  def pass
    OpenSSL::HMAC.hexdigest("SHA256", secret, "preview-pass")
  end

  def headers
    guarded? ? { HEADER => pass } : {}
  end

  # Where a browser opens the preview: through the gate, which sets its cookie.
  def entry_url
    return @project.preview_url unless guarded?

    expires = TICKET_TTL.from_now.to_i
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "enter:#{expires}")
    "#{@project.preview_url}/_preview/enter?#{{ ticket: "#{expires}--#{signature}" }.to_query}"
  end

  private
    def secret_path
      @project.path.join("tmp/preview_secret")
    end
end
