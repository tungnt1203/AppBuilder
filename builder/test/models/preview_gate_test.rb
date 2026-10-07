require "test_helper"

class PreviewGateTest < ActiveSupport::TestCase
  # The template's side of the gate, as the preview runs it.
  TEMPLATE_GATE = Module.new.tap do |scope|
    source = Rails.configuration.x.template_path.join("config/initializers/preview_gate.rb").read
    scope.module_eval(source.sub("if Rails.env.development?", "if true").sub(/^\s*Rails\.application\.config\.middleware.*$/, ""))
  end::PreviewGate

  setup do
    @root = Pathname(Dir.mktmpdir)
    @original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, @root
    @project = projects(:clinic)
    @gate = @project.preview_gate
  end

  teardown do
    Rails.configuration.x.projects_root = @original_root
    @root.rmtree
  end

  test "an app made before the gate stays open" do
    assert_not @gate.guarded?
    assert_equal @project.preview_url, @gate.entry_url
    assert_empty @gate.headers
  end

  test "lets the builder in the way the app checks" do
    guard

    secret = @gate.secret
    assert_equal secret, @gate.secret
    assert_equal 0o600, @project.path.join("tmp/preview_secret").stat.mode & 0o777

    ticket = Rack::Utils.parse_query(URI(@gate.entry_url).query)["ticket"]
    assert TEMPLATE_GATE.ticket_valid?(secret, ticket)
    assert_not TEMPLATE_GATE.ticket_valid?("another secret", ticket)
    travel(PreviewGate::TICKET_TTL + 1.second) { assert_not TEMPLATE_GATE.ticket_valid?(secret, ticket) }

    assert_equal({ "X-Preview-Pass" => TEMPLATE_GATE.pass(secret) }, @gate.headers)
  end

  private
    def guard
      @project.path.join("config/initializers").mkpath
      @project.path.join("config/initializers/preview_gate.rb").write("")
    end
end
