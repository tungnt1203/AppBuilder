require "test_helper"

class SharesControllerTest < ActionDispatch::IntegrationTest
  # Whether the preview is up, as the test says; nil leaves it to the real check.
  module Running
    mattr_accessor :value
    def running? = Running.value.nil? ? super : Running.value
  end
  PreviewServer.prepend(Running)

  setup do
    @project = projects(:clinic)
    Running.value = true
  end

  teardown { Running.value = nil }

  test "the owner shares the preview and stops sharing it" do
    sign_in_as users(:owner)

    post project_share_path(@project)
    token = @project.reload.share_token
    assert token
    get project_path(@project)
    assert_select "input[value='#{shared_preview_url(token)}']"

    assert_changes -> { @project.reload.preview_version } do
      delete project_share_path(@project)
    end
    assert_nil @project.share_token
    get shared_preview_path(token)
    assert_response :not_found
  end

  test "anyone with the link gets into the preview, without an account" do
    @project.share_preview

    get shared_preview_path(@project.share_token)

    assert_redirected_to @project.preview_gate.entry_url
  end

  test "a preview that isn't running is woken up" do
    @project.share_preview
    Running.value = false

    get shared_preview_path(@project.share_token)

    assert_response :service_unavailable
    assert_select "meta[http-equiv=refresh]"
  end

  test "someone else can't share or stop sharing an app that isn't theirs" do
    sign_in_as users(:member)

    post project_share_path(@project)
    assert_response :not_found
    assert_nil @project.reload.share_token
  end
end
