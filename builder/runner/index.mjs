// Runs one agent turn with the Claude Agent SDK and prints every SDK message as
// one JSON line on stdout, the same format as `claude -p --output-format stream-json`.
//
//   node runner/index.mjs --cwd DIR --prompt TEXT --config FILE [--resume SESSION_ID] [--permission-mode plan]
//
// FILE is JSON with allowedTools, disallowedTools, appendSystemPrompt and maxBudgetUsd.
// Needs ANTHROPIC_API_KEY in the environment.
import { readFileSync } from "node:fs"
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

for await (const message of query({
  prompt: args.prompt,
  options: {
    cwd: args.cwd,
    resume: args.resume,
    permissionMode: args["permission-mode"],
    includePartialMessages: true,
    allowedTools: config.allowedTools,
    disallowedTools: config.disallowedTools,
    settingSources: [ "project" ],
    systemPrompt: { type: "preset", preset: "claude_code", append: config.appendSystemPrompt },
    maxBudgetUsd: config.maxBudgetUsd
  }
})) {
  process.stdout.write(JSON.stringify(message) + "\n")
}
