require "test_helper"

class ProjectPreviewTest < ActiveSupport::TestCase
  class FakePreview
    attr_reader :calls

    def initialize(problem: nil) = (@problem, @calls = problem, [])
    def restart = @calls << :restart
    def start = @calls << :start
    def check = @problem
  end

  setup { @project = projects(:clinic) }

  test "a preview that answers is running, and the iframe reloads" do
    preview = with_preview(FakePreview.new) { |project| project.define_singleton_method(:prepare_preview) { nil } }

    assert_difference -> { @project.reload.preview_version } do
      @project.restart_preview
    end
    assert @project.preview_running?
    assert_nil @project.preview_error
    assert_equal [ :restart ], preview.calls
  end

  test "what the check finds is kept for the owner" do
    with_preview(FakePreview.new(problem: "NameError in ShopsController#show")) { |project| project.define_singleton_method(:prepare_preview) { nil } }

    @project.restart_preview(restart: false)

    assert @project.preview_broken?
    assert_equal "NameError in ShopsController#show", @project.preview_error
  end

  test "a failed migration is the problem, even if the server comes up" do
    with_preview(FakePreview.new)

    @project.restart_preview # the fixture's folder doesn't exist, so db:prepare fails

    assert @project.preview_broken?
    assert_match "bin/rails db:prepare failed", @project.preview_error
  end

  test "an unexpected error never leaves the preview starting" do
    broken = FakePreview.new
    broken.define_singleton_method(:restart) { raise "boom" }
    with_preview(broken) { |project| project.define_singleton_method(:prepare_preview) { nil } }

    assert_raises(RuntimeError) { @project.restart_preview }
    assert @project.reload.preview_broken?
    assert_equal "RuntimeError: boom", @project.preview_error
  end

  test "what the preview pane shows" do
    [ @project, projects(:shop) ].each { |project| project.define_singleton_method(:built?) { true } }

    assert_equal "live", @project.preview_state
    assert_equal "building", projects(:shop).preview_state

    projects(:shop).update!(planning: true)
    assert_equal "live", projects(:shop).preview_state, "planning doesn't change the app"

    @project.update!(preview_status: :starting)
    assert_equal "starting", @project.preview_state
    @project.update!(preview_status: :broken)
    assert_equal "broken", @project.preview_state
    assert_equal "setup", Project.new(status: :setting_up).preview_state
  end

  test "before the first build the starter app stays covered" do
    project = projects(:clinic)
    project.define_singleton_method(:built?) { false }
    assert_equal "blank", project.preview_state

    project.update!(status: :working, planning: true)
    assert_equal "blank", project.preview_state
    project.update!(planning: false)
    assert_equal "building", project.preview_state
  end

  private
    def with_preview(preview)
      @project.define_singleton_method(:preview) { preview }
      yield @project if block_given?
      preview
    end
end
