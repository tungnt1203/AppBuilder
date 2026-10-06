require "test_helper"

class ThumbnailTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @project = projects(:clinic)
    @thumbnail = @project.thumbnail
  end

  teardown { @thumbnail.delete }

  test "without Chrome there is no picture, and nothing fails" do
    with_chrome("/nonexistent/chrome") do
      assert_not @thumbnail.capture
    end
    assert_not @thumbnail.exist?
    assert_nil @thumbnail.version
  end

  test "keeps what Chrome saved" do
    chrome = Rails.root.join("tmp/fake-chrome")
    chrome.write(<<~SH)
      #!/bin/sh
      for arg; do case "$arg" in --screenshot=*) printf png > "${arg#--screenshot=}";; esac; done
    SH
    chrome.chmod(0o755)

    with_chrome(chrome) { assert @thumbnail.capture }
    assert_equal "png", @thumbnail.path.read
    assert @thumbnail.version
  ensure
    chrome.delete
  end

  test "a working preview gets a new picture" do
    @project.define_singleton_method(:prepare_preview) { nil }
    preview = Object.new
    def preview.restart = nil
    def preview.check = nil
    @project.define_singleton_method(:preview) { preview }

    assert_enqueued_with(job: ThumbnailJob, args: [ @project ]) { @project.restart_preview }
  end

  private
    def with_chrome(path)
      original, Rails.configuration.x.chrome_bin = Rails.configuration.x.chrome_bin, path.to_s
      yield
    ensure
      Rails.configuration.x.chrome_bin = original
    end
end
