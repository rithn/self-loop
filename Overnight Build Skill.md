# Overnight Build Skill (`/code-overnight`)

> Type `/code-overnight [project idea]` to autonomously design, spec, ticket, and build a working demo app while you sleep — no intervention needed.

Linked to [[AI assisted work]] and [[Coding loops]].

---

## What it does

Takes a project idea (from argument or context) and runs the full overnight pipeline without asking you questions:

1. **Reads vault context** — client files, projects.md, daily tasks — to understand the business purpose
2. **Makes all design decisions autonomously** — stack, scope, features, demo flow
3. **Writes `app_spec.txt`** — full architecture, API design, DB schema, service logic, UI design
4. **Writes `tickets.md`** — 15–25 atomic tickets (one focused change each)
5. **Writes `builder.md` and `verifier.md`** — agent prompts with context persistence via `agent_notes.md`
6. **Copies `run_build_verify_loop.sh`** from an existing project
7. **Copies AWS credentials** from the nearest project that has them
8. **Git inits** the project directory
9. **Starts the build-verify loop** in a named tmux session (1 ticket per cycle)
10. **Starts the heartbeat monitor** in a second tmux pane to restart if stuck
11. After loop completes: runs `post_build.sh` → testability audit → app testing → UI testing

You wake up to a working, tested demo.

---

## Ticket design rules (baked in)

- **One concern per ticket** — one file, one function, one endpoint, one UI section
- **Verifiable** — every ticket has bash commands that confirm it works; no "manual check" tickets
- **Incremental** — each ticket builds on the previous; nothing assumes future tickets exist
- **Scaffolding first** — project setup, DB, models before any business logic
- **Frontend last** — HTML structure → JS interactions → results rendering → history table

---

## Context persistence (agent_notes.md)

Each builder cycle:
1. Reads `prompts/agent_notes.md` at the start (restores state from previous cycle)
2. Implements the ticket
3. Writes `prompts/agent_notes.md` at the end (last ticket, current state, files created, known issues, next ticket)

This prevents context window exhaustion on long overnight runs. The verifier also reads `agent_notes.md` before verifying.

---

## Post-build chain

After all tickets complete, `scripts/post_build.sh` runs automatically:

| Step | Skill | What it does |
|------|-------|-------------|
| 1 | `/code-testability-audit` | Audits tickets for untestable steps, fixes blockers in-place |
| 2 | `/code-app-testing` | Generates and runs full test suite (unit + integration) |
| 3 | `/code-ui-testing` | Playwright visual tests against the running app |

---

## Heartbeat monitor

A separate tmux pane runs `scripts/heartbeat.sh` alongside the build loop. It checks every 10 minutes:
- Is the tmux session still alive?
- Has `loop.log` been updated in the last 30 minutes?
- Is the `.done` sentinel present (loop finished)?

If stuck → kills the stale session, marks in-progress tickets as INTERRUPTED, restarts the loop. Logs every action to `scripts/agent-run-logs/{run-name}/heartbeat.log`.

---

## Autonomous decisions made by the skill

The skill makes all of these without asking:

| Decision | How it decides |
|----------|---------------|
| Tech stack | FastAPI + vanilla HTML/JS — matches existing projects, no build step |
| Port | 8000 (standard across all projects) |
| AWS credentials | Copies from nearest project with `AWS_ACCESS_KEY_ID` in `.env` |
| Bedrock model | Uses `AWS_MODEL_ID` from copied credentials |
| DB | SQLite for demos (no infra needed) |
| Ticket count | 15–25 depending on scope (1 per cycle) |
| Demo scope | Narrowed to what can be built and demoed in one overnight session |
| Sample data | Creates synthetic sample files that produce visible, meaningful output |

---

## When to use

- You have a client meeting in 3–7 days and need a working demo
- The use case is clear enough to specify without a call (or you've had the call)
- You want to wake up to something runnable, not a plan

## When NOT to use

- You don't have a clear use case yet → run `/plan-ideate` first
- The build needs real client data to work → set up data access first
- The demo needs a non-standard stack (mobile app, hardware, etc.)

---

## Files it creates

```
~/Documents/{project-name}/
  prompts/
    app_spec.txt       ← full spec
    tickets.md         ← atomic tickets
    builder.md         ← builder agent prompt
    verifier.md        ← verifier agent prompt
    agent_notes.md     ← context persistence (written by builder each cycle)
    plan.md            ← business logic reference (optional)
  scripts/
    run_build_verify_loop.sh
    post_build.sh
    heartbeat.sh
    agent-run-logs/{run-name}/
      loop.log
      build_report.md
      .ticket_progress
      heartbeat.log
  .env                 ← copied from nearest project with AWS creds
  .env.required
  .gitignore
```

---

## Skill file location

`~/.claude/commands/code-overnight.md`

---

*Created: 19 March 2026*
