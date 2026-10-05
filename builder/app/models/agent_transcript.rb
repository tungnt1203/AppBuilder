# Follows one agent turn event by event and shows the owner how the work is going:
#
# - the current activity ("Thinking", "Reading app/models/patient.rb") with a live clock
# - the reply as it's being written
# - the plan, when the agent writes one as tasks, ticked off as it goes
# - every step taken, including how long it thought
#
# Thinking happens but its content isn't returned by the model, so the owner sees
# that and how long it thinks, not what.
class AgentTranscript
  DRAFT_INTERVAL = 0.3 # seconds between live updates of the reply being written

  STEPS = {
    "Read" => ->(input) { "Read #{relative(input["file_path"])}" },
    "Write" => ->(input) { "Created #{relative(input["file_path"])}" },
    "Edit" => ->(input) { "Edited #{relative(input["file_path"])}" },
    "Grep" => ->(input) { "Searched for “#{input["pattern"].to_s.truncate(60)}”" },
    "Glob" => ->(input) { "Looked for #{input["pattern"]}" },
    "Bash" => ->(input) { "Ran #{input["command"].to_s.truncate(120)}" },
    "Skill" => ->(input) { "Followed the #{input["skill"] || input["name"]} guide" }
  }

  ACTIVITIES = {
    "Read" => ->(input) { "Reading #{relative(input["file_path"])}" },
    "Write" => ->(input) { "Writing #{relative(input["file_path"])}" },
    "Edit" => ->(input) { "Editing #{relative(input["file_path"])}" },
    "Grep" => ->(_) { "Searching the code" },
    "Glob" => ->(_) { "Looking through files" },
    "Bash" => ->(input) { input["command"].to_s.start_with?("bin/rails test") ? "Running the tests" : "Running #{input["command"].to_s.truncate(60)}" },
    "TaskCreate" => ->(_) { "Planning" },
    "TaskUpdate" => ->(_) { "Updating the plan" }
  }

  def self.relative(path)
    path.to_s.sub(%r{\A.*?/projects/[^/]+/}, "")
  end

  def initialize(project, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @project, @clock = project, clock
    @thinking_since = {}
    @draft = +""
    @draft_flushed_at = 0
    @pending_tasks = {}
  end

  def record(event)
    return if event["parent_tool_use_id"] # work done by subagents

    case event["type"]
    when "system" then record_session(event)
    when "stream_event" then record_stream(event["event"] || {})
    when "assistant" then record_message(event.dig("message", "content"))
    when "user" then record_tool_results(event.dig("message", "content"))
    when "result" then record_result(event)
    end
  end

  def finish
    show_activity(nil)
    clear_draft
  end

  private
    def record_session(event)
      @project.update!(session_id: event["session_id"]) if event["subtype"] == "init" && event["session_id"]
    end

    # Partial events arrive while a block is being written.
    def record_stream(stream)
      case stream["type"]
      when "content_block_start"
        block = stream["content_block"] || {}
        case block["type"]
        when "thinking"
          @thinking_since[stream["index"]] = @clock.()
          show_activity "Thinking"
        when "text"
          show_activity "Writing a reply"
        when "tool_use"
          show_activity ACTIVITIES.key?(block["name"]) ? "Working" : "Using #{block["name"]}"
        end
      when "content_block_delta"
        if stream.dig("delta", "type") == "text_delta"
          @draft << stream.dig("delta", "text").to_s
          flush_draft
        end
      when "content_block_stop"
        record_thought(@thinking_since.delete(stream["index"]))
      end
    end

    def record_thought(since)
      return unless since

      seconds = (@clock.() - since).round
      @project.messages.create!(role: :action, body: "Thought for #{seconds} #{"second".pluralize(seconds)}", data: { tool: "Thinking", seconds: seconds }) if seconds >= 1
    end

    # Complete messages: the final text of the reply and each tool call with its input.
    def record_message(content)
      Array(content).each do |block|
        case block["type"]
        when "text"
          next if block["text"].blank?
          clear_draft
          @project.messages.create!(role: :assistant, body: block["text"])
        when "tool_use"
          record_tool_use(block)
        end
      end
    end

    def record_tool_use(block)
      input = block["input"] || {}
      name = block["name"]

      if (describe = ACTIVITIES[name])
        show_activity describe.(input)
      end

      case name
      when "TaskCreate" then @pending_tasks[block["id"]] = input["subject"].to_s
      when "TaskUpdate" then update_task(input["taskId"].to_s, input["status"])
      else
        if (step = STEPS[name])
          @project.messages.create!(role: :action, body: step.(input), data: { tool: name })
        end
      end
    end

    def record_tool_results(content)
      Array(content).each do |block|
        next unless block["type"] == "tool_result" && (subject = @pending_tasks.delete(block["tool_use_id"]))

        id = tool_result_text(block)[/Task #(\d+)/, 1] || (plan_tasks.size + 1).to_s
        update_plan { |tasks| tasks << { "id" => id, "subject" => subject, "status" => "pending" } }
      end
      show_activity "Thinking"
    end

    def record_result(event)
      @project.messages.create!(
        role: event["is_error"] ? :error : :result,
        body: event["is_error"] ? event["result"].to_s : "",
        data: event.slice("total_cost_usd", "num_turns", "duration_ms", "subtype")
      )
    end

    # The plan for this turn is one message whose tasks get ticked off.
    def plan
      @plan ||= @project.messages.create!(role: :plan, data: { "tasks" => [] })
    end

    def plan_tasks
      @plan ? @plan.data["tasks"] : []
    end

    def update_plan
      tasks = plan.data["tasks"].map(&:dup)
      yield tasks
      plan.update!(data: plan.data.merge("tasks" => tasks))
    end

    def update_task(id, status)
      return unless @plan && status.present?

      update_plan { |tasks| tasks.find { |task| task["id"] == id }&.store("status", status) }
    end

    def tool_result_text(block)
      content = block["content"]
      content.is_a?(Array) ? content.filter_map { |part| part["text"] }.join : content.to_s
    end

    def show_activity(text)
      return if text == @activity

      @activity = text
      @project.update_column(:activity, text)
      Turbo::StreamsChannel.broadcast_update_to(@project, target: "activity-text", html: ERB::Util.html_escape(text.to_s))
    end

    def flush_draft
      return if @clock.() - @draft_flushed_at < DRAFT_INTERVAL

      @draft_flushed_at = @clock.()
      Turbo::StreamsChannel.broadcast_update_to(@project, target: "draft", html: ApplicationController.helpers.markdown(@draft))
    end

    def clear_draft
      @draft = +""
      Turbo::StreamsChannel.broadcast_update_to(@project, target: "draft", html: "")
    end
end
