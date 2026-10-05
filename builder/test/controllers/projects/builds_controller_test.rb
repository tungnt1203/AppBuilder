require "test_helper"

class Projects::BuildsControllerTest < ActionDispatch::IntegrationTest
  test "approving the proposed plan builds it" do
    project = projects(:clinic)
    project.messages.create!(role: :assistant, body: "Kế hoạch…", data: { "proposal" => true })

    assert_enqueued_with(job: AgentTurnJob, args: [ project, "Làm theo kế hoạch này", "build" ]) do
      post project_build_path(project)
    end
    assert_equal "Làm theo kế hoạch này", project.messages.user.last.body
  end

  test "nothing to build without a proposal waiting" do
    assert_no_enqueued_jobs { post project_build_path(projects(:clinic)) }
  end
end
