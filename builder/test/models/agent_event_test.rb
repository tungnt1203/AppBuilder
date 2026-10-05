require "test_helper"

class AgentEventTest < ActiveSupport::TestCase
  setup { @project = projects(:shop) }

  test "remembers the session so the next turn continues it" do
    record "type" => "system", "subtype" => "init", "session_id" => "abc"

    assert_equal "abc", @project.reload.session_id
  end

  test "shows replies and file changes, hides reading" do
    assert_difference -> { @project.messages.count }, 3 do
      record "type" => "assistant", "parent_tool_use_id" => nil, "message" => { "content" => [
        { "type" => "text", "text" => "Mình sẽ thêm bảng bệnh nhân." },
        { "type" => "tool_use", "name" => "Read", "input" => { "file_path" => "/x/projects/shop/app/models/user.rb" } },
        { "type" => "tool_use", "name" => "Write", "input" => { "file_path" => "/x/projects/shop/app/models/patient.rb" } },
        { "type" => "tool_use", "name" => "Bash", "input" => { "command" => "bin/rails test" } }
      ] }
    end

    assert_equal [ "assistant", "action", "action" ], @project.messages.last(3).map(&:role)
    assert_equal [ "Created app/models/patient.rb", "Ran bin/rails test" ], @project.messages.last(2).map(&:body)
  end

  test "ignores work done by subagents" do
    assert_no_difference -> { @project.messages.count } do
      record "type" => "assistant", "parent_tool_use_id" => "tool_1", "message" => { "content" => [ { "type" => "text", "text" => "inner" } ] }
    end
  end

  test "summarizes the turn" do
    record "type" => "result", "is_error" => false, "result" => "Done", "total_cost_usd" => 1.23, "num_turns" => 40, "duration_ms" => 300_000

    message = @project.messages.last
    assert message.result?
    assert_equal 40, message.data["num_turns"]
  end

  test "reports failed turns" do
    record "type" => "result", "is_error" => true, "result" => "Budget exceeded"

    assert_equal [ "error", "Budget exceeded" ], [ @project.messages.last.role, @project.messages.last.body ]
  end

  private
    def record(event)
      AgentEvent.new(@project, event).record
    end
end
