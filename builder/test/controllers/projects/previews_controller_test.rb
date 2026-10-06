require "test_helper"

class Projects::PreviewsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "trying a broken preview again restarts it" do
    project = projects(:clinic)
    project.update!(preview_status: :broken, preview_error: "boom")

    assert_enqueued_with(job: PreviewStartJob, args: [ project, { restart: true } ]) do
      post project_preview_path(project)
    end
    assert project.reload.preview_starting?
    assert_nil project.preview_error
  end

  test "not while the agent is working" do
    assert_no_enqueued_jobs { post project_preview_path(projects(:shop)) }
  end
end
