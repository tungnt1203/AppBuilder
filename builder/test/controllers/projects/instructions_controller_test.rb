require "test_helper"

class Projects::InstructionsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "saving the agent's instructions for an app" do
    patch project_instructions_path(projects(:clinic)), params: { project: { instructions: "Never use pink." } }

    assert_redirected_to project_path(projects(:clinic))
    assert_equal "Never use pink.", projects(:clinic).reload.instructions
  end

  test "instructions that are too long are refused" do
    patch project_instructions_path(projects(:clinic)), params: { project: { instructions: "a" * 4001 } }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_nil projects(:clinic).reload.instructions
  end
end
