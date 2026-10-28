// Runs one agent turn with the Claude Agent SDK, interactively.
//
//   node runner/index.mjs --cwd DIR --prompt TEXT --config FILE [--resume SESSION_ID [--fork-session]] [--permission-mode plan]
//
// stdout: every SDK message as one JSON line (the same format as
//   `claude -p --output-format stream-json`), plus builder events:
//   {"type":"builder_ask","id":"…","questions":[…]}   the agent asks the owner something;
//                                                     the turn ends and the answers start the next one
//   {"type":"builder_activity","text":"…"}             what the runner itself is doing (checking the app)
//   {"type":"builder_check","passed":true,"summary":"…"} how the app's tests went before the turn ended
//
// stdin: commands from the builder, one JSON line each:
//   {"type":"message","text":"…"}                      the owner adds to the request mid-turn
//   {"type":"interrupt"}                               the owner pressed Stop
//
// The agent also gets the builder's own tools (look at the app, finish the turn), a design
// reviewer to ask once it has built, and before a build turn ends the app's tests run: when
// they fail, the agent is sent back to fix them (twice at most).
//
// FILE is JSON with allowedTools, disallowedTools, appendSystemPrompt, maxBudgetUsd, and
// optionally fallbackModel, effort and check (run the tests before the turn ends).
// Authenticates with CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY from the environment.
import { execFile } from "node:child_process"
import { readFileSync, writeFileSync, mkdirSync } from "node:fs"
import { join, resolve } from "node:path"
import { createInterface } from "node:readline"
import { parseArgs, promisify } from "node:util"
import { query, tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk"
import { z } from "zod"

const { values: args } = parseArgs({
  options: {
    cwd: { type: "string" },
    prompt: { type: "string" },
    config: { type: "string" },
    resume: { type: "string" },
    "fork-session": { type: "boolean", default: false },
    "permission-mode": { type: "string", default: "acceptEdits" }
  }
})

const config = JSON.parse(readFileSync(args.config, "utf8"))
const emit = (event) => process.stdout.write(JSON.stringify(event) + "\n")
const run = promisify(execFile)

// A command in the app's folder: [output, succeeded]. A failing command is an answer, not an error.
async function inApp(command, argv, timeout) {
  try {
    const { stdout, stderr } = await run(command, argv, { cwd: args.cwd, timeout, maxBuffer: 20 * 1024 * 1024 })
    return [ `${stdout}${stderr}`.trim(), true ]
  } catch (error) {
    return [ `${error.stdout ?? ""}${error.stderr ?? ""}`.trim() || String(error.message), false ]
  }
}

// The builder's tools, in this process. look: bin/look, with its screenshots handed straight to
// the agent instead of files to Read. finish_turn: the version's name and what to ask for next.
const MAX_SCREENSHOTS = 8

const look = tool(
  "look",
  "Look at pages of the running app (the preview) in a browser at phone and desktop width, the way a visitor " +
    "sees them: returns the screenshots and the problems a visitor would run into (error pages, JavaScript " +
    "errors, broken images, a page wider than the phone, links that fail). Also takes another site's URL " +
    "(one the owner likes) for screenshots of it.",
  {
    paths: z.array(z.string()).min(1).max(4).optional().describe("Paths of the app like \"/\" or \"/products\", or full URLs; default \"/\""),
    width: z.enum([ "both", "phone", "desktop" ]).optional().describe("Which widths; default both"),
    screens: z.number().int().min(1).max(6).optional().describe("Screens to capture per page, from the top; default 3")
  },
  async ({ paths, width, screens }) => {
    const argv = [ ...(paths ?? [ "/" ]) ]
    if (width === "phone") argv.push("--phone")
    if (width === "desktop") argv.push("--desktop")
    if (screens) argv.push("--screens", String(screens))

    const [ output ] = await inApp("bin/look", argv, 240_000)
    const files = [ ...output.matchAll(/^\s*screenshots: (.+)$/gm) ].flatMap((match) => match[1].split(", ")).slice(0, MAX_SCREENSHOTS)
    const images = files.flatMap((file) => {
      try {
        return [ { type: "image", data: readFileSync(resolve(args.cwd, file)).toString("base64"), mimeType: "image/png" } ]
      } catch {
        return []
      }
    })
    return { content: [ { type: "text", text: output || "bin/look printed nothing." }, ...images ] }
  },
  { annotations: { readOnlyHint: true } }
)

const finishTurn = tool(
  "finish_turn",
  "Call once, just before your final reply, when you changed the app in this turn: names the new version " +
    "in the app's history, and offers the owner what to ask for next as buttons.",
  {
    commit_message: z.string().min(3).max(100).describe("What changed, in English, starting with a verb, under 72 characters: \"Add a monthly sales report\""),
    next_steps: z.array(z.string().min(3).max(120)).max(3).optional()
      .describe("Up to 3 things the owner could ask for next that the app doesn't do yet, each a request they could send as is, in English, under 60 characters")
  },
  async ({ commit_message, next_steps }) => {
    mkdirSync(join(args.cwd, "tmp"), { recursive: true })
    writeFileSync(join(args.cwd, "tmp/commit_message.txt"), commit_message.trim() + "\n")
    // The builder reads next_steps from this call in the transcript.
    return { content: [ { type: "text", text: "Saved. Now write your short final reply to the owner and end your turn." } ] }
  }
)

const builderTools = createSdkMcpServer({ name: "builder", version: "1.0.0", tools: [ look, finishTurn ], alwaysLoad: true })

// A second pair of eyes on the app, asked once after building: it looks and lists what to fix,
// and changes nothing itself.
const DESIGN_REVIEWER = {
  description: "A picky shop designer who looks at the app's pages at phone and desktop width and lists what " +
    "to fix. Ask it once after you built the app or visibly changed pages, naming the pages to look at.",
  prompt: `You review a small online shop's pages for its owner, like a senior shop designer who
designs with Hallmark would.
Use the look tool on the pages you were given (both widths), then read the views behind anything
that needs a closer look. Change nothing.

Look for, in order of how much it hurts the shop:
- the phone: anything wider than the screen, text too small to read, buttons too small to tap,
  a first screen that doesn't show what the shop sells, things squashed or overlapping;
- what breaks Hallmark, the storefront's design system (.claude/skills/hallmark: the Floor in
  SKILL.md, the gates in references/gates.md, and the material named in the first line of
  app/assets/tailwind/theme.css, references/themes/<slug>.md): eyebrows, labels in tracked
  capitals, middle-dot meta, invented reviews or numbers, emoji as icons, stock phrases, a page
  that strays from its material's faces, surfaces and controls, every section the same shape;
- broken or missing images, low contrast, inconsistent spacing, type or corners;
- anything a buyer can't find or do (price, add to cart, sizes, how shipping works).

Answer with at most 6 problems, the worst first. For each: the page and width, what's wrong in
one sentence, and the concrete fix (which file, what to change). No praise, no summary.
If nothing worth fixing is left, say so in one line.`,
  tools: [ "mcp__builder__look", "Read", "Glob", "Grep" ],
  model: "sonnet",
  maxTurns: 12
}

// Before a build turn ends, the app's tests run on what it changed. When they fail, the agent
// is sent back once more to fix them, twice at most, so a turn can't loop on a stubborn test.
const MAX_SENT_BACK = 2
let sentBack = 0
// A turn that changed how the app looks (a few views, styles, scripts or the theme) is shown to
// the design reviewer first, once: left to itself, the agent rarely asks.
const LOOKS = /^(app\/(views|assets|javascript)|config\/theme)/
const REVIEW_AFTER = 3
let reviewed = false

async function changedFiles() {
  const [ status, ok ] = await inApp("git", [ "status", "--porcelain" ], 30_000)
  return ok ? status.split("\n").filter(Boolean).map((line) => line.slice(3)) : []
}

async function checkBeforeStopping() {
  if (!config.check || sentBack >= MAX_SENT_BACK) return {}
  const files = await changedFiles()
  if (files.length === 0) return {}

  if (!reviewed && files.filter((file) => LOOKS.test(file)).length >= REVIEW_AFTER) {
    reviewed = true
    return {
      decision: "block",
      reason: "Before you finish: ask the design-reviewer agent to look at the pages you built or changed (the home " +
        "page, a product page and any others), and wait for its answer. Then fix every problem it lists that you " +
        "can fix in the app's code (layout, sizes, spacing, wording, what shows on the phone's first screen); leave " +
        "only what needs the owner, like their own photos or products. Call finish_turn again and write one short " +
        "final reply that says what the app does now and what you improved after the review."
    }
  }

  emit({ type: "builder_activity", text: "Running the app's tests" })
  const [ output, passed ] = await inApp("bin/rails", [ "test" ], 600_000)
  const summary = output.split("\n").reverse().find((line) => /\d+ runs?, \d+ assertions?/.test(line)) ?? ""
  emit({ type: "builder_check", passed, summary: summary.trim() })
  if (passed) return {}

  sentBack += 1
  return {
    decision: "block",
    reason: "The app's tests fail after your changes, so the turn can't end yet. Fix the app (or a test that " +
      `no longer matches what the owner asked for), then finish again.\n\n${output.slice(-6000)}`
  }
}

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
    forkSession: args["fork-session"],
    permissionMode: args["permission-mode"],
    includePartialMessages: true,
    allowedTools: config.allowedTools,
    disallowedTools: config.disallowedTools,
    settingSources: [ "project" ],
    systemPrompt: { type: "preset", preset: "claude_code", append: config.appendSystemPrompt },
    maxBudgetUsd: config.maxBudgetUsd,
    // Overloaded or unavailable, the turn goes on with the backup model instead of failing.
    ...(config.fallbackModel && { fallbackModel: config.fallbackModel }),
    ...(config.effort && { effort: config.effort }),
    mcpServers: { builder: builderTools },
    agents: { "design-reviewer": DESIGN_REVIEWER },
    hooks: { Stop: [ { hooks: [ async () => (interrupted ? {} : checkBeforeStopping()) ], timeout: 660 } ] },
    // One reviewer at a time, and reviewers don't spawn agents of their own.
    env: { ...process.env, CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH: "1", CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS: "1" },
    canUseTool
  }
})

let interrupted = false

createInterface({ input: process.stdin }).on("line", (line) => {
  let command
  try { command = JSON.parse(line) } catch { return }

  if (command.type === "message") inbox.push(command.text)
  if (command.type === "interrupt") {
    interrupted = true
    conversation.interrupt()
    inbox.close()
  }
})

for await (const message of conversation) {
  emit(message)
  if (message.type === "result" && inbox.items.length === 0) inbox.close()
}

process.exit(0)
