# Overnight Build Skill (`/code-overnight`)

> Type `/code-overnight [project idea]` to autonomously design, spec, ticket, and build a working demo app while you sleep — no intervention needed.

---

## What it does

Takes a project idea (from argument or vault context) and runs the full overnight pipeline without asking questions. Reads client files, `projects.md`, and `company.md` first to understand the business purpose.

1. **Derives a project slug** and creates the directory at `~/Documents/{slug}/`
2. **Copies AWS credentials** from the nearest project that has them in `.env`
3. **Writes `prompts/app_spec.txt`** — full architecture, API design, DB schema, service logic, UI design, sample data
4. **Writes `prompts/tickets.md`** — 15–25 atomic tickets, reconciled against the spec to confirm every endpoint is covered
5. **Writes `prompts/builder.md`** — includes a ticket anchoring rule (builder implements ONLY the first unchecked ticket), server startup/health check pattern, ticket status update discipline, and `agent_notes.md` context persistence
6. **Writes `prompts/verifier.md`** — includes a ticket status gate (verifier immediately fails if builder didn't mark ticket `[x]`), same server startup pattern, and commit-on-pass behaviour
7. **Writes `scripts/post_build.sh`** — runs after all tickets complete: testability audit → app testing → UI testing, with logs going to `scripts/post-build-logs/`
8. **Writes `scripts/heartbeat.sh`** — monitors the loop and restarts if stuck
9. **Copies `run_build_verify_loop.sh`** from an existing project, verifies it has 5 required behaviours, and rewrites from scratch if any are missing
10. **Git inits** the project and makes an initial commit
11. **Starts the build-verify loop** in a named tmux session (1 ticket per cycle)
12. **Starts the heartbeat monitor** in a second tmux pane

You wake up to a working, tested demo.

---

## The loop script — 5 required behaviours

The copied `run_build_verify_loop.sh` is checked for these after copying:

1. **`env -u CLAUDECODE`** on every `claude` invocation — prevents nested session crash
2. **Port 8000 freed before every cycle** — `lsof -ti:8000 | xargs kill -9`, followed by a check that the port is actually free before handing off to the builder
3. **Stall detection** — tracks ticket count; if unchanged for `MAX_RETRIES` consecutive cycles, logs `ABORT` and touches `.done`
4. **Dynamic build report path** — injects `Build report path: $BUILD_REPORT` at the end of both builder and verifier task strings so neither prompt hardcodes a path
5. **Post-build hook** — when all tickets are marked `[x]`, executes `bash scripts/post_build.sh`

If any of these checks fail, the script is rewritten from scratch.

---

## Context persistence (`agent_notes.md`)

Each builder cycle:
1. Reads `prompts/agent_notes.md` at the start (restores state from previous cycle)
2. Implements the ticket
3. Writes `prompts/agent_notes.md` at the end — last completed ticket, current state, files created, known issues, next ticket (kept under 50 lines, overwritten each cycle)

This prevents context window exhaustion on long overnight runs. The verifier also reads `agent_notes.md` before verifying.

---

## Post-build chain

After all tickets complete, `scripts/post_build.sh` runs automatically:

| Step | Skill | What it does |
|------|-------|-------------|
| 1 | `/code-testability-audit` | Audits tickets for untestable steps, fixes blockers in-place |
| 2 | `/code-app-testing` | Generates and runs full test suite (unit + integration) |
| 3 | `/code-ui-testing` | Playwright visual tests against the running app |

Each step logs to `scripts/post-build-logs/`. The script exits 1 if any step fails to output its completion marker.

---

## Heartbeat monitor

A separate tmux pane runs `scripts/heartbeat.sh` alongside the build loop. Every 10 minutes:
- If `scripts/heartbeat.stop` exists → exits cleanly
- If `.done` sentinel exists → logs "loop complete" and exits
- Reads the last log line timestamp from `loop.log` — if more than 30 minutes ago, declares stuck
- On stuck: kills the stale tmux session, marks in-progress tickets as INTERRUPTED, restarts the loop from `scripts/.loop-cmd`

The loop command is written to `scripts/.loop-cmd` at startup so the heartbeat always restarts with identical flags.

---

## Autonomous decisions

| Decision | Default |
|----------|---------|
| Tech stack | FastAPI + vanilla HTML/JS, SQLite, AWS Bedrock |
| Port | 8000 |
| AWS credentials | Copied from nearest project with `AWS_ACCESS_KEY_ID` in `.env` |
| Bedrock model | Uses `AWS_MODEL_ID` from copied credentials |
| Auth | None (demo) |
| File storage | Local `uploads/` directory |
| Risk colors | LOW=#22c55e, MEDIUM=#f59e0b, HIGH=#ef4444 |
| Sample data | 3–5 synthetic files with deliberate contradictions/anomalies |
| Ticket count | 15–25, one per cycle |
| Health endpoint | `GET /health` → `{"status": "ok"}` — required in every app, always in TICKET-001 |

---

## When to use

- You have a client meeting in 3–7 days and need a working demo
- The use case is clear enough to specify without a call (or you've had the call)
- You want to wake up to something runnable, not a plan

## When NOT to use

- You don't have a clear use case yet → run `/plan-ideate` first
- The demo needs a non-standard stack (mobile app, hardware, etc.)
- The project scope is too large for one night → use `/code-evolve` instead

---

## Files created

```
~/Documents/{project-name}/
  prompts/
    app_spec.txt       ← full spec (XML)
    tickets.md         ← atomic tickets with status checkboxes
    builder.md         ← builder agent prompt
    verifier.md        ← verifier agent prompt
    agent_notes.md     ← context persistence (builder writes each cycle)
  scripts/
    run_build_verify_loop.sh
    post_build.sh
    heartbeat.sh
    .loop-cmd          ← exact launch command for heartbeat restarts
    agent-run-logs/{run-name}/
      loop.log
      build_report.md
      .ticket_progress
      heartbeat.log
    post-build-logs/
  .env                 ← copied from nearest project with AWS creds
  .env.required
  .gitignore
```
