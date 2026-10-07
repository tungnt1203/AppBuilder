// Runs one agent turn with the Claude Agent SDK, interactively.
//
//   node runner/index.mjs --cwd DIR --prompt TEXT --config FILE [--resume SESSION_ID] [--permission-mode plan]
//
// stdout: every SDK message as one JSON line (the same format as
//   `claude -p --output-format stream-json`), plus builder events:
//   {"type":"builder_ask","id":"…","questions":[…]}   the agent asks the owner something;
//                                                     the turn ends and the answers start the next one
//
// stdin: commands from the builder, one JSON line each:
//   {"type":"message","text":"…"}                      the owner adds to the request mid-turn
//   {"type":"interrupt"}                               the owner pressed Stop
//
// FILE is JSON with allowedTools, disallowedTools, appendSystemPrompt and maxBudgetUsd.
// Authenticates with CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY from the environment.
import { readFileSync } from "node:fs"
import { createInterface } from "node:readline"
import { parseArgs } from "node:util"
import { query } from "@anthropic-ai/claude-agent-sdk"

const { values: args } = parseArgs({
  options: {
    cwd: { type: "string" },
    prompt: { type: "string" },
    config: { type: "string" },
    resume: { type: "string" },
    "permission-mode": { type: "string", default: "acceptEdits" }
  }
})

const config = JSON.parse(readFileSync(args.config, "utf8"))
const emit = (event) => process.stdout.write(JSON.stringify(event) + "\n")

// The owner's messages, fed to the agent one at a time. The turn ends once the
// agent has answered everything that's been sent.
const inbox = {
  items: [],
  closed: false,
  push(text) {
    this.items.push({ type: "user", message: { role: "user", content: text }, parent_tool_use_id: null })
    this.wake?.()
  },
  close() {
    this.closed = true
    this.wake?.()
  },
  async *[Symbol.asyncIterator]() {
    while (true) {
      if (this.items.length) yield this.items.shift()
      else if (this.closed) return
      else await new Promise((resolve) => (this.wake = resolve))
    }
  }
}

const QUESTIONS_SHOWN = "The studio is showing your questions to the owner. End your turn now without " +
  "writing anything else; their answers will come as their next message."

// Questions don't keep the turn (and a job worker) waiting for the owner, who may
// answer hours later: the studio shows them, the turn ends, and the answers come
// back as the owner's next message in this session. (Denying with interrupt: true
// would end the turn as an error.)
async function canUseTool(toolName, input, { toolUseID }) {
  if (toolName === "AskUserQuestion") {
    emit({ type: "builder_ask", id: toolUseID ?? crypto.randomUUID(), questions: input.questions })
    return { behavior: "deny", message: QUESTIONS_SHOWN }
  }

  if (toolName === "ExitPlanMode") {
    return { behavior: "deny", message: "The owner reviews the plan in the studio and approves it with a button. Stop here." }
  }

  // Not a broken tool: say what to do instead, or the agent ends its turn thinking its tools failed.
  if (toolName === "Bash") {
    return { behavior: "deny", message: "That command isn't allowed here; your tools still work. Run each command " +
      "on its own, without cd (you're already in the app's folder), pipes, ; or $(...): for example " +
      "`bin/rails tailwindcss:build`, then `bin/look / /products`. Use Read, Grep and Glob to look at files." }
  }
  return { behavior: "deny", message: `${toolName} isn't available in the builder; your other tools still work.` }
}

inbox.push(args.prompt)

const conversation = query({
  prompt: inbox,
  options: {
    cwd: args.cwd,
    resume: args.resume,
    permissionMode: args["permission-mode"],
    includePartialMessages: true,
    allowedTools: config.allowedTools,
    disallowedTools: config.disallowedTools,
    settingSources: [ "project" ],
    systemPrompt: { type: "preset", preset: "claude_code", append: config.appendSystemPrompt },
    maxBudgetUsd: config.maxBudgetUsd,
    canUseTool
  }
})

createInterface({ input: process.stdin }).on("line", (line) => {
  let command
  try { command = JSON.parse(line) } catch { return }

  if (command.type === "message") inbox.push(command.text)
  if (command.type === "interrupt") {
    conversation.interrupt()
    inbox.close()
  }
})

for await (const message of conversation) {
  emit(message)
  if (message.type === "result" && inbox.items.length === 0) inbox.close()
}

process.exit(0)
