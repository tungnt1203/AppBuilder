# Turns agent events into chat messages the owner can follow.
class AgentEvent
  # Tools worth showing in the chat; reading and searching would only be noise.
  ACTIONS = {
    "Write" => ->(input) { "Created #{relative(input["file_path"])}" },
    "Edit" => ->(input) { "Edited #{relative(input["file_path"])}" },
    "Bash" => ->(input) { "Ran #{input["command"].to_s.truncate(120)}" }
  }

  def self.relative(path)
    path.to_s.sub(%r{\A.*?/projects/[^/]+/}, "")
  end

  def initialize(project, event)
    @project, @event = project, event
  end

  def record
    case @event["type"]
    when "system" then record_session
    when "assistant" then record_assistant
    when "result" then record_result
    end
  end

  private
    def record_session
      @project.update!(session_id: @event["session_id"]) if @event["subtype"] == "init" && @event["session_id"]
    end

    def record_assistant
      return if @event["parent_tool_use_id"] # work done by subagents

      Array(@event.dig("message", "content")).each do |block|
        case block["type"]
        when "text"
          @project.messages.create!(role: :assistant, body: block["text"]) if block["text"].present?
        when "tool_use"
          if describe = ACTIONS[block["name"]]
            @project.messages.create!(role: :action, body: describe.(block["input"] || {}), data: { tool: block["name"] })
          end
        end
      end
    end

    def record_result
      @project.messages.create!(
        role: @event["is_error"] ? :error : :result,
        body: @event["is_error"] ? @event["result"].to_s : "",
        data: @event.slice("total_cost_usd", "num_turns", "duration_ms", "subtype")
      )
    end
end
