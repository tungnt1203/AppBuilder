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
  QUESTIONS = /```questions\s*(\[.*?\])\s*```/m
  NEXT_STEPS = /```next\s*(\[.*?\])\s*```/m

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
    when "builder_ask" then record_ask(event)
    end
  end

  def finish
    show_activity(nil)
    clear_draft
  end

  # The agent asked the owner something, which ends the turn until they answer.
  def asked?
    @asked
  end

  # The agent reported the end of its turn.
  def finished?
    @finished
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
        if stream.dig("delta", "type") == "text_delta" && !asked?
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
          next if block["text"].blank? || asked? # the agent's sign-off after its questions
          clear_draft
          record_reply(block["text"])
        when "tool_use"
          record_tool_use(block)
        end
      end
    end

    # The interactive agent asks with AskUserQuestion; the answers start the next turn.
    def record_ask(event)
      questions = Array(event["questions"]).map do |question|
        options = Array(question["options"])
        { "question" => question["question"].to_s, "header" => question["header"].to_s,
          "options" => options.map { |option| option["label"].to_s },
          "descriptions" => options.map { |option| option["description"].to_s },
          "multiple" => question["multiSelect"] == true }
      end

      clear_draft
      @project.messages.create!(role: :assistant, body: "", data: { "questions" => questions })
      @asked = true
    end

    # Without the interactive agent, questions come at the end of a reply in a
    # ```questions block; they become buttons too. After building, the agent suggests
    # what to ask for next in a ```next block, which becomes buttons as well.
    def record_reply(text)
      data = {}
      if (questions = parse_questions(text[QUESTIONS, 1]))
        data["questions"] = questions
        text = text.sub(QUESTIONS, "")
      end
      if (next_steps = parse_next_steps(text[NEXT_STEPS, 1]))
        data["next_steps"] = next_steps
        text = text.sub(NEXT_STEPS, "")
      end
      @project.messages.create!(role: :assistant, body: data.any? ? text.strip : text, data: data)
    end

    def parse_next_steps(json)
      return unless json

      Array(JSON.parse(json)).filter_map { |step| step.strip.truncate(120) if step.is_a?(String) && step.present? }.first(3).presence
    rescue JSON::ParserError
      nil
    end

    def parse_questions(json)
      return unless json

      Array(JSON.parse(json)).filter_map do |item|
        next unless item.is_a?(Hash) && item["question"].present?
        { "question" => item["question"].to_s, "options" => Array(item["options"]).map(&:to_s).first(4) }
      end.presence
    rescue JSON::ParserError
      nil
    end

    def record_tool_use(block)
      input = block["input"] || {}
      name = block["name"]

      if (describe = ACTIVITIES[name])
        show_activity describe.(input)
      end

      # Plan mode writes its plan file outside the app; it isn't a change to the app.
      if name == "Write" && !inside_project?(input["file_path"])
        return @project.messages.create!(role: :action, body: "Wrote the plan", data: { tool: "Plan" })
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

    def inside_project?(path)
      path.to_s.start_with?("#{@project.path}/")
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
      @finished = true
      # A turn the owner stopped ends "with an error" that says nothing: it's just stopped.
      error = event["is_error"] && event["result"].to_s.strip.presence && !@project.stop_requested?

      # A failed turn often repeats its last reply as the error; show it once, as the error.
      if error && (last = @project.messages.last)&.assistant? && last.body.strip == event["result"].to_s.strip
        last.destroy
      end

      data = event.slice("total_cost_usd", "num_turns", "duration_ms", "subtype")
      data["stopped"] = true if event["is_error"] && !error
      @project.messages.create!(role: error ? :error : :result, body: error ? event["result"].to_s : "", data:)
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
      Turbo::StreamsChannel.broadcast_update_to(@project, targets: ".live-activity", html: ERB::Util.html_escape(text.to_s))
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
