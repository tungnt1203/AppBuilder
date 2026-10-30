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
    "Bash" => ->(input) { command(input["command"]).first },
    "Skill" => ->(input) { "Followed the #{input["skill"] || input["name"]} guide" },
    "mcp__builder__look" => ->(input) { "Looked at #{Array(input["paths"]).presence&.to_sentence || "/"}" },
    "Agent" => ->(input) { input["subagent_type"] == "design-reviewer" ? "Asked the design reviewer to look at the app" : "Asked a helper: #{input["description"].to_s.truncate(80)}" }
  }

  ACTIVITIES = {
    "Read" => ->(input) { "Reading #{relative(input["file_path"])}" },
    "Write" => ->(input) { "Writing #{relative(input["file_path"])}" },
    "Edit" => ->(input) { "Editing #{relative(input["file_path"])}" },
    "Grep" => ->(_) { "Searching the code" },
    "Glob" => ->(_) { "Looking through files" },
    "Bash" => ->(input) { command(input["command"]).last },
    "TaskCreate" => ->(_) { "Planning" },
    "TaskUpdate" => ->(_) { "Updating the plan" },
    "mcp__builder__look" => ->(_) { "Looking at the app" },
    "mcp__builder__finish_turn" => ->(_) { "Wrapping up" },
    "mcp__builder__propose_plan" => ->(_) { "Writing the plan" },
    "Agent" => ->(input) { input["subagent_type"] == "design-reviewer" ? "The design reviewer is looking at the app" : "A helper is working" }
  }

  # The app's own commands, said as what they do: [ step, activity ] by the command's start.
  COMMANDS = [
    [ /\Abin\/rails test/, ->(_) { [ "Ran the tests", "Running the tests" ] } ],
    [ /\Abin\/rails tailwindcss:build/, ->(_) { [ "Rebuilt the styles", "Rebuilding the styles" ] } ],
    [ /\Abin\/rubocop/, ->(_) { [ "Checked the code's style", "Checking the code's style" ] } ],
    [ /\Abin\/look\s*(.*)/, ->(m) { pages = m[1].split.grep(%r{\A(/|https?://)}).presence&.to_sentence || "/"; [ "Looked at #{pages}", "Looking at the app" ] } ],
    [ /\Abin\/sloplint/, ->(_) { [ "Checked the pages against Hallmark", "Checking the pages against Hallmark" ] } ],
    [ /\Abin\/theme material ([\w-]+)/, ->(m) { [ "Put the #{m[1].titleize} material in place", "Putting the #{m[1].titleize} material in place" ] } ],
    [ /\Abin\/theme ([\w-]+)/, ->(m) { [ "Put the #{m[1]} layout in place", "Putting the #{m[1]} layout in place" ] } ],
    [ /\Abin\/images\s+(?:--\S+\s+\S+\s+)*["']?([^"'-][^"']*)/, ->(m) { [ "Searched photos of “#{m[1].strip.truncate(60)}”", "Looking for photos" ] } ],
    [ /\Abin\/icons\s+(.*)/, ->(m) { [ "Looked for icons: #{m[1].delete(%q("')).truncate(40)}", "Looking for icons" ] } ],
    [ /\Abin\/request\s+["']?(.*?)["']?\z/, ->(m) { [ "Asked the Platform: #{m[1].truncate(80)}", "Asking the Platform" ] } ],
    [ /\Anode \S*hallmark\/scripts\/theme\.mjs deal/, ->(_) { [ "Dealt three Hallmark materials to choose from", "Choosing a material" ] } ],
    [ /\Anode \S*hallmark\/scripts\/theme\.mjs draw/, ->(_) { [ "Drew the page's hero, menu and footer", "Planning the page" ] } ],
    [ /\Anode \S*hallmark\/scripts\/theme\.mjs log/, ->(_) { [ "Noted the design in Hallmark's log", "Noting the design" ] } ],
    [ /\Anode \S*hallmark\/scripts\/sloplint/, ->(_) { [ "Checked the pages against Hallmark", "Checking the pages against Hallmark" ] } ]
  ].freeze

  def self.relative(path)
    path.to_s.sub(%r{\A.*?/projects/[^/]+/}, "")
  end

  # What the owner reads for a shell command: without the "cd <the app's folder> &&" in front or
  # the app's folder in paths, in words for the app's own commands. [ step, activity ]
  def self.command_text(text)
    text.to_s.strip.sub(/\Acd\s+("[^"]*"|\S+)\s*(&&|;)\s*/, "").gsub(%r{\S*/projects/[^/\s]+/}, "")
  end

  def self.command(text)
    text = command_text(text)
    pattern, words = COMMANDS.find { |pattern, _| text.match?(pattern) }
    pattern ? words.(text.match(pattern)) : [ "Ran #{text.truncate(120)}", "Running #{text.truncate(60)}" ]
  end

  def initialize(project, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @project, @clock = project, clock
    @thinking_since = {}
    @draft = +""
    @draft_flushed_at = 0
    @pending_tasks = {}
    @viewable = {}
    @materials = {}
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
    when "builder_activity" then show_activity(event["text"].to_s.presence)
    when "builder_check" then record_check(event)
    end
  end

  def finish
    show_activity(nil)
    clear_draft
    offer_next_steps
    show_plan_card
  end

  # The agent asked the owner something, which ends the turn until they answer.
  def asked?
    @asked
  end

  # The agent reported the end of its turn.
  def finished?
    @finished
  end

  # The session to resume wasn't found where the agent runs (it ran somewhere else before,
  # or its settings were removed): the turn didn't start.
  def lost_session?
    @lost_session
  end

  private
    def record_session(event)
      return unless event["subtype"] == "init" && event["session_id"]
      return if event["session_id"] == @project.session_id

      @project.remember_session(event["session_id"])
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

    # The interactive agent names what to ask for next with finish_turn, just before its reply;
    # they go on the turn's last reply as buttons, unless it has questions or steps already.
    def offer_next_steps
      return unless @next_steps

      reply = @project.messages.assistant.last
      return unless reply && reply.data["questions"].blank? && reply.data["next_steps"].blank?

      reply.update!(data: reply.data.merge("next_steps" => @next_steps))
      @next_steps = nil
    end

    # The plan the agent named with propose_plan goes on its last reply, which the studio shows as
    # a card (messages/_plan_card) above the button that builds it.
    def show_plan_card
      return unless @plan_card

      reply = @project.messages.assistant.last
      reply&.update!(data: reply.data.merge("plan_card" => @plan_card))
      @plan_card = nil
    end

    def plan_card(input)
      lines = ->(key) { Array(input[key]).map { |line| line.to_s.squish.truncate(160) }.compact_blank.first(10) }
      look = input["look"].to_h.slice("slug", "why").transform_values { |value| value.to_s.squish.truncate(200) }
      look = nil unless look["slug"].to_s.match?(/\A[\w-]+\z/)
      { "summary" => input["summary"].to_s.squish.truncate(400), "look" => look, "layout" => input["layout"].to_s.squish.presence,
        "composition" => input["composition"].to_s.squish.truncate(200).presence,
        "home" => lines.("home"), "pages" => lines.("pages"), "chosen" => lines.("chosen"), "owner" => lines.("owner") }.compact_blank
    end

    # The builder ran the app's tests before letting the turn end.
    def record_check(event)
      summary = event["summary"].to_s.presence
      body = event["passed"] ? "Checked the app's tests: they pass#{" (#{summary})" if summary}" : "The app's tests failed; fixing them"
      @project.messages.create!(role: :action, body:, data: { tool: "Check", passed: event["passed"] == true })
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
      @viewable[block["id"]] = true if viewable?(block["name"], block["input"] || {})
      if block["name"] == "Bash" && (slug = self.class.command_text(block.dig("input", "command"))[/\Abin\/theme material ([\w-]+)/, 1])
        @materials[block["id"]] = slug
      end
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
      when "mcp__builder__finish_turn" then @next_steps = parse_next_steps(Array(input["next_steps"]).to_json)
      when "mcp__builder__propose_plan" then @plan_card = plan_card(input)
      when "TaskCreate" then @pending_tasks[block["id"]] = input["subject"].to_s
      when "TaskUpdate" then update_task(input["taskId"].to_s, input["status"])
      else
        if (step = STEPS[name])
          @project.messages.create!(role: :action, body: step.(input), data: { tool: name })
        end
      end
    end

    # The shop just took a Hallmark material: a card in the chat with its picture, the colors and
    # the faces it gave the shop, as they are at this moment.
    def record_look(slug)
      theme = ProjectTheme.new(@project)
      material = theme.material
      return unless material&.slug == slug

      @project.messages.create!(role: :notice, body: "The look: #{material.name}",
        data: { "look" => { "slug" => slug, "name" => material.name, "summary" => material.summary }.merge(theme.palette) })
    end

    VIEWABLE_COMMANDS = /\A(bin\/look|bin\/rails tailwindcss:build|bin\/sloplint|bin\/theme)/

    def viewable?(name, input)
      name == "mcp__builder__look" || (name == "Bash" && self.class.command_text(input["command"]).match?(VIEWABLE_COMMANDS))
    end

    def inside_project?(path)
      path.to_s.start_with?("#{@project.path}/")
    end

    def record_tool_results(content)
      # The agent just looked at the app or rebuilt its styles: the app is in a state to see, so
      # the studio shows it as it is now instead of a "building" screen.
      @project.show_work_in_progress if Array(content).any? { |block| block["type"] == "tool_result" && @viewable.delete(block["tool_use_id"]) }
      Array(content).each do |block|
        slug = block["type"] == "tool_result" && @materials.delete(block["tool_use_id"])
        record_look(slug) if slug && !block["is_error"]
      end

      Array(content).each do |block|
        next unless block["type"] == "tool_result" && (subject = @pending_tasks.delete(block["tool_use_id"]))

        id = tool_result_text(block)[/Task #(\d+)/, 1] || (plan_tasks.size + 1).to_s
        update_plan { |tasks| tasks << { "id" => id, "subject" => subject, "status" => "pending" } }
      end
      show_activity "Thinking"
    end

    def record_result(event)
      @finished = true
      errors = Array(event["errors"]).map(&:to_s)
      return @lost_session = true if event["is_error"] && errors.any? { |error| error.start_with?("No conversation found") }

      # A turn the owner stopped ends "with an error" that says nothing: it's just stopped.
      problem = event["result"].to_s.strip.presence || errors.join("\n").presence
      error = event["is_error"] && problem && !@project.stop_requested?

      # A failed turn often repeats its last reply as the error; show it once, as the error.
      if error && (last = @project.messages.last)&.assistant? && last.body.strip == problem
        last.destroy
      end

      data = event.slice("total_cost_usd", "num_turns", "duration_ms", "subtype")
      data["cost_usd"] = charge_turn(event["total_cost_usd"])
      data["stopped"] = true if event["is_error"] && !error
      @project.messages.create!(role: error ? :error : :result, body: error ? problem : "", data:)
    end

    # A resumed session reports what it has cost in all, from its first turn: this turn
    # costs what was added since the last one counted.
    def charge_turn(session_total)
      return unless session_total

      counted = @project.session_cost_usd.to_f
      cost = session_total.to_f >= counted ? session_total.to_f - counted : session_total.to_f
      @project.chat.update!(session_cost_usd: session_total)
      @project.owner.usages.create!(project: @project, cost_usd: cost) if @project.owner && cost.positive?
      cost.round(4)
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
