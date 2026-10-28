require "test_helper"

class AgentTranscriptTest < ActiveSupport::TestCase
  setup do
    @project = projects(:shop)
    @now = 0.0
    @transcript = AgentTranscript.new(@project, clock: -> { @now })
  end

  test "remembers the session so the next turn continues it" do
    record "type" => "system", "subtype" => "init", "session_id" => "abc"

    assert_equal "abc", @project.reload.session_id
  end

  test "shows the reply, file reads and changes as steps" do
    assert_difference -> { @project.messages.count }, 4 do
      record "type" => "assistant", "message" => { "content" => [
        { "type" => "text", "text" => "Mình sẽ thêm bảng bệnh nhân." },
        { "type" => "tool_use", "name" => "Read", "input" => { "file_path" => "#{@project.path}/app/models/user.rb" } },
        { "type" => "tool_use", "name" => "Write", "input" => { "file_path" => "#{@project.path}/app/models/patient.rb" } },
        { "type" => "tool_use", "name" => "Bash", "input" => { "command" => "bin/rails test" } }
      ] }
    end

    assert_equal [ "Read app/models/user.rb", "Created app/models/patient.rb", "Ran the tests" ], @project.messages.action.last(3).map(&:body)
    assert_equal "Running the tests", @project.reload.activity
  end

  test "a plan file written outside the app isn't a change" do
    record "type" => "assistant", "message" => { "content" => [
      { "type" => "tool_use", "name" => "Write", "input" => { "file_path" => "/Users/x/.claude/plans/nail.md" } }
    ] }

    assert_equal [ "Wrote the plan", "Plan" ], [ @project.messages.last.body, @project.messages.last.data["tool"] ]
  end

  test "records how long it thought, without the content" do
    stream "type" => "content_block_start", "index" => 0, "content_block" => { "type" => "thinking" }
    assert_equal "Thinking", @project.reload.activity

    @now = 7.4
    stream "type" => "content_block_stop", "index" => 0

    assert_equal "Thought for 7 seconds", @project.messages.last.body
  end

  test "turns tasks into a plan that gets ticked off" do
    record "type" => "assistant", "message" => { "content" => [
      { "type" => "tool_use", "id" => "t1", "name" => "TaskCreate", "input" => { "subject" => "Tạo bảng sản phẩm" } },
      { "type" => "tool_use", "id" => "t2", "name" => "TaskCreate", "input" => { "subject" => "Làm trang đơn hàng" } }
    ] }
    record "type" => "user", "message" => { "content" => [
      { "type" => "tool_result", "tool_use_id" => "t1", "content" => "Task #1 created successfully: Tạo bảng sản phẩm" },
      { "type" => "tool_result", "tool_use_id" => "t2", "content" => [ { "type" => "text", "text" => "Task #2 created successfully" } ] }
    ] }
    record "type" => "assistant", "message" => { "content" => [
      { "type" => "tool_use", "id" => "t3", "name" => "TaskUpdate", "input" => { "taskId" => "1", "status" => "completed" } }
    ] }

    plan = @project.messages.plan.sole
    assert_equal [ [ "Tạo bảng sản phẩm", "completed" ], [ "Làm trang đơn hàng", "pending" ] ], plan.data["tasks"].map { |task| task.values_at("subject", "status") }
  end

  test "turns a questions block into buttons and hides it from the reply" do
    record "type" => "assistant", "message" => { "content" => [ { "type" => "text", "text" => <<~TEXT } ] }
      Mình cần hỏi trước khi lập kế hoạch.

      ```questions
      [{"question": "Khách có cần tài khoản không?", "options": ["Không", "Có"]}]
      ```
    TEXT

    reply = @project.messages.last
    assert_equal "Mình cần hỏi trước khi lập kế hoạch.", reply.body
    assert_equal [ { "question" => "Khách có cần tài khoản không?", "options" => [ "Không", "Có" ] } ], reply.data["questions"]
  end

  test "keeps a malformed questions block as plain text" do
    record "type" => "assistant", "message" => { "content" => [ { "type" => "text", "text" => "Hỏi:\n```questions\n[not json]\n```" } ] }

    assert_includes @project.messages.last.body, "not json"
  end

  test "turns a next block into suggested requests and hides it from the reply" do
    record "type" => "assistant", "message" => { "content" => [ { "type" => "text", "text" => <<~TEXT } ] }
      Đã thêm trang đặt lịch.

      ```next
      ["Thêm trang báo cáo doanh thu", "Cho khách đặt lịch online", "Gửi nhắc lịch qua Zalo", "Thứ tư"]
      ```
    TEXT

    reply = @project.messages.last
    assert_equal "Đã thêm trang đặt lịch.", reply.body
    assert_equal [ "Thêm trang báo cáo doanh thu", "Cho khách đặt lịch online", "Gửi nhắc lịch qua Zalo" ], reply.data["next_steps"]
  end

  test "next steps from finish_turn go on the turn's last reply" do
    record "type" => "assistant", "message" => { "content" => [
      { "type" => "tool_use", "id" => "toolu_9", "name" => "mcp__builder__finish_turn",
        "input" => { "commit_message" => "Add booking", "next_steps" => [ "Add a price list", "Send reminders", "Take deposits", "One too many" ] } } ] }
    record "type" => "assistant", "message" => { "content" => [ { "type" => "text", "text" => "Đã thêm trang đặt lịch." } ] }
    @transcript.finish

    assert_equal [ "Add a price list", "Send reminders", "Take deposits" ], @project.messages.assistant.last.data["next_steps"]
  end

  test "the builder's check of the app's tests shows as a step, and while it runs" do
    record "type" => "builder_activity", "text" => "Running the app's tests"
    assert_equal "Running the app's tests", @project.reload.activity

    record "type" => "builder_check", "passed" => false, "summary" => "39 runs, 2 failures"
    record "type" => "builder_check", "passed" => true, "summary" => "39 runs, 0 failures"

    assert_equal [ "The app's tests failed; fixing them", "Checked the app's tests: they pass (39 runs, 0 failures)" ], @project.messages.action.last(2).map(&:body)
  end

  test "looking at the app and asking the design reviewer are steps" do
    record "type" => "assistant", "message" => { "content" => [
      { "type" => "tool_use", "id" => "toolu_1", "name" => "mcp__builder__look", "input" => { "paths" => [ "/", "/products" ] } },
      { "type" => "tool_use", "id" => "toolu_2", "name" => "Agent", "input" => { "subagent_type" => "design-reviewer", "description" => "Review" } } ] }

    assert_equal [ "Looked at / and /products", "Asked the design reviewer to look at the app" ], @project.messages.action.last(2).map(&:body)
  end

  test "keeps a malformed next block as plain text" do
    record "type" => "assistant", "message" => { "content" => [ { "type" => "text", "text" => "Xong.\n```next\n[oops\n```" } ] }

    assert_includes @project.messages.last.body, "oops"
    assert_nil @project.messages.last.data["next_steps"]
  end

  test "a question from AskUserQuestion becomes buttons and ends the turn" do
    record "type" => "builder_ask", "id" => "toolu_1", "questions" => [
      { "question" => "Khách có cần tài khoản không?", "header" => "Tài khoản", "multiSelect" => false,
        "options" => [ { "label" => "Không", "description" => "Ai cũng đặt được" }, { "label" => "Có", "description" => "Phải đăng ký" } ] }
    ]

    ask = @project.messages.last
    assert_equal [ "Không", "Có" ], ask.data["questions"].first["options"]
    assert_equal [ "Ai cũng đặt được", "Phải đăng ký" ], ask.data["questions"].first["descriptions"]
    assert @transcript.asked?
  end

  test "hides what the agent writes after asking" do
    record "type" => "builder_ask", "id" => "toolu_1", "questions" => [ { "question" => "Khách có cần tài khoản không?", "options" => [] } ]

    assert_no_difference -> { @project.messages.count } do
      record "type" => "assistant", "message" => { "content" => [ { "type" => "text", "text" => "Đã gửi câu hỏi, chờ bạn trả lời." } ] }
    end
    assert @project.messages.last.data["questions"].present?
  end

  test "ignores work done by subagents" do
    assert_no_difference -> { @project.messages.count } do
      record "type" => "assistant", "parent_tool_use_id" => "tool_1", "message" => { "content" => [ { "type" => "text", "text" => "inner" } ] }
    end
  end

  test "summarizes the turn and reports failures" do
    record "type" => "result", "is_error" => false, "total_cost_usd" => 1.23, "num_turns" => 40, "duration_ms" => 300_000
    assert_equal 40, @project.messages.last.data["num_turns"]

    record "type" => "result", "is_error" => true, "result" => "Budget exceeded"
    assert_equal [ "error", "Budget exceeded" ], [ @project.messages.last.role, @project.messages.last.body ]
  end

  test "charges each turn to the app's owner" do
    assert_difference -> { @project.owner.usages.count } do
      record "type" => "result", "is_error" => false, "total_cost_usd" => 1.23, "num_turns" => 4, "duration_ms" => 1000
    end
    assert_equal [ @project.id, 1.23 ], [ Usage.last.project_id, Usage.last.cost_usd.to_f ]
  end

  test "a resumed session is charged only what each turn added" do
    record "type" => "system", "subtype" => "init", "session_id" => "s1"
    record "type" => "result", "is_error" => false, "total_cost_usd" => 6.53, "num_turns" => 200
    record "type" => "system", "subtype" => "init", "session_id" => "s1"
    record "type" => "result", "is_error" => false, "total_cost_usd" => 6.60, "num_turns" => 1

    assert_equal [ 6.53, 0.07 ], @project.owner.usages.where(project: @project).order(:id).last(2).map { |usage| usage.cost_usd.to_f.round(2) }
    assert_equal 0.07, @project.messages.result.last.data["cost_usd"].round(2)

    record "type" => "system", "subtype" => "init", "session_id" => "s2"
    record "type" => "result", "is_error" => false, "total_cost_usd" => 0.16, "num_turns" => 3
    assert_equal 0.16, @project.owner.usages.last.cost_usd.to_f
  end

  test "a stopped turn is summed up, not shown as an empty error" do
    @project.agent_commands.create!(kind: :interrupt)
    @project.update!(working_since: 1.minute.ago)
    record "type" => "result", "is_error" => true, "subtype" => "error_during_execution", "result" => "", "total_cost_usd" => 0.55, "num_turns" => 16, "duration_ms" => 36_000

    message = @project.messages.last
    assert_equal [ "result", "", true ], [ message.role, message.body, message.data["stopped"] ]
  end

  test "an error with nothing to say is not shown as an error" do
    record "type" => "result", "is_error" => true, "subtype" => "error_during_execution", "result" => ""
    assert_equal "result", @project.messages.last.role
  end

  test "an error the agent reports in its list of errors is shown" do
    record "type" => "result", "is_error" => true, "subtype" => "error_during_execution", "result" => "", "errors" => [ "Credit balance is too low" ]
    assert_equal [ "error", "Credit balance is too low" ], [ @project.messages.last.role, @project.messages.last.body ]
  end

  test "a session that can't be resumed is noted, not shown" do
    assert_no_difference -> { @project.messages.count } do
      record "type" => "result", "is_error" => true, "subtype" => "error_during_execution", "result" => "",
             "errors" => [ "No conversation found with session ID: 5f412df2" ]
    end
    assert @transcript.lost_session?
  end

  test "an error that repeats the last reply shows once" do
    record "type" => "assistant", "message" => { "content" => [ { "type" => "text", "text" => "You've hit your session limit" } ] }
    record "type" => "result", "is_error" => true, "result" => "You've hit your session limit"

    assert_equal [ "error" ], @project.messages.where(body: "You've hit your session limit").pluck(:role)
  end

  test "clears the activity when the turn ends" do
    stream "type" => "content_block_start", "index" => 0, "content_block" => { "type" => "text" }
    @transcript.finish

    assert_nil @project.reload.activity
  end

  private
    def record(event)
      @transcript.record(event)
    end

    def stream(event)
      record "type" => "stream_event", "event" => event
    end

  test "a shell command reads as what it does, without the app's folder" do
    assert_equal "Put the Sticker material in place", AgentTranscript.command("cd /home/dev/projects/ab12cd34 && bin/theme material sticker").first
    assert_equal "Looked at / and /products", AgentTranscript.command("bin/look / /products --screens 3").first
    assert_equal "Searched photos of “retro cat lover”", AgentTranscript.command(%q(bin/images --count 5 "retro cat lover")).first
    assert_equal [ "Ran the tests", "Running the tests" ], AgentTranscript.command("bin/rails test test/controllers")
    assert_equal "Ran ls app/views", AgentTranscript.command("cd \"/srv/projects/ab12cd34\"; ls /srv/projects/ab12cd34/app/views").first
  end

  test "once the agent has looked at the app, the studio shows it while it's being built" do
    @project.update!(status: :working)
    transcript = AgentTranscript.new(@project)
    transcript.record("type" => "assistant", "message" => { "content" => [ { "type" => "tool_use", "id" => "look-1", "name" => "Bash", "input" => { "command" => "bin/look / /products" } } ] })
    assert_not @project.reload.showing_progress?

    transcript.record("type" => "user", "message" => { "content" => [ { "type" => "tool_result", "tool_use_id" => "look-1", "content" => "No problems found." } ] })
    assert @project.reload.showing_progress?
  end
end
