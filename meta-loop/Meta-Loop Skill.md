# Meta-Loop Skill (`/code-evolve`)

> Type `/code-evolve [project idea or slug]` to autonomously evolve a software project towards a long-term goal — running multiple build-test-assess cycles overnight without intervention.

---

## Context read on startup

Before doing anything else, the skill reads any available context files in the working directory — `Context System/projects.md`, `Context System/company.md`, and any client file in `Clients & Partners/` relevant to the project argument. Files that don't exist are silently skipped. If none are found, it proceeds directly to the scenario detection step.

---

## What it does

Takes a project idea or slug and runs the full pipeline — from goal setting to working, tested app — through up to N outer loop iterations. Each iteration runs the inner build loop, post-build testing chain, and then assesses progress against `goal.md` before deciding whether to continue.

---

## Phase 1 — Goal conversation (if `goal.md` doesn't exist yet)

An interactive conversation that produces `prompts/goal.md`. Works through five topics:

1. **Purpose and audience** — who uses this, what problem it solves, what earns trust in 30 seconds
2. **The money-shot** — the single capability that must be excellent; if this is mediocre, nothing else matters
3. **Success criteria** — 5–8 measurable criteria, challenged for specificity: "is this measuring quality or just presence?" Each must be verifiable by a bash command or a specific UI action in Playwright
4. **Static vs. core split** — what gets built once and left alone (auth, DB, upload flow) vs. what gets refined every iteration (the money-shot feature, output quality, key UI moments)
5. **Constraints and scope** — stack, non-goals, max iterations

See [goal-conversation.md](./goal-conversation.md) for the full conversation design and [goal-template.md](./goal-template.md) for the `goal.md` format.

---

## Phase 2 — Outer loop (up to N iterations)

The skill detects its scenario through a two-level check on startup:

**Level 1 — does `goal.md` exist?**
- No → run Phase 1 goal conversation, then scaffold
- Yes → check Level 2

**Level 2 — does `run_outer_loop.sh` exist?**
- No → scaffold (skip goal conversation)
- Yes → inspect previous run state:

| Case | Condition | Action |
|---|---|---|
| A — Fully complete | Outer log ends with "Outer loop finished", no FAILED tickets | Prompt for more iterations → update `MAX_ITERATIONS` → append resume directive → loop |
| B — Finished with failures | Outer log ends with "Outer loop finished" but FAILED tickets exist | Show summary of failed tickets, prompt: relaunch or abort? |
| C — Interrupted | Outer log does NOT end with "Outer loop finished" | Calculate remaining iterations from log, update script, relaunch |

**Case B user prompt:**
> "Previous run finished but X ticket(s) failed: [list]. Options: 1. Relaunch — loop will retry failed tickets. 2. Abort — investigate manually before relaunching."

Only proceeds if the user chooses relaunch. If they choose abort, the skill stops.

### Resume — Case A detail

When Case A triggers, before launching the loop the skill does two things:

1. Updates `MAX_ITERATIONS` in `run_outer_loop.sh` to the new number the user requested
2. Appends a **continue directive** to `prompts/spec_update_brief.md`:
   > "The previous run completed all tickets successfully. Do NOT return Action: COMPLETE. Extend the app further — identify gaps, edge cases, polish, or new capabilities. Every new ticket must map to a specific success criterion from goal.md."

This prevents the outer loop agent from reading the completed state and immediately exiting — it forces another round of extension work.

---

### Each outer loop iteration

```
0. Sync spec with reality
   → reconciles app_spec.txt against actual code (git log, file structure, CLAUDE.md)
   → handles manual edits made between iterations

1. Read goal.md + synced spec + last test results + UI screenshots
   → assess: what works, what's missing, what needs changing

2. Decide: done or continue?
   → all success criteria met, or max iterations reached → write final report, stop

3. Write prompts/spec_update_brief.md
   → instructions for /code-create-spec Extend Mode (specific, not vague)
   → includes: what to keep, regressions to fix first, core refinement targets, ticket numbering

4. /code-create-spec Extend Mode
   → updates app_spec.txt, appends new tickets to tickets.md

5. /code-build-loop
   → iteration 1: generates builder.md and verifier.md
   → iteration 2+: reuses existing builder.md/verifier.md

6. run_build_verify_loop.sh (same --run-name across all iterations)
   → .ticket_progress persists — completed tickets are never re-run
   → .done sentinel deleted before each restart

7. post_build.sh
   → /code-testability-audit → /code-app-testing → /code-ui-testing

8. Back to step 0
```

**Why step 0 (spec sync) matters:** `app_spec.txt` is the intended state; the actual code is the real state. These drift from manual edits, slightly-different implementations, and newly discovered constraints. Without syncing first, the outer loop would plan on top of a stale spec — potentially re-adding things already built or overwriting things that changed.

---

## How it differs from `/code-overnight`

| | `/code-overnight` | `/code-evolve` |
|---|---|---|
| **Runs** | Once | Up to N outer loop iterations |
| **Spec** | Written once at start | Updated each iteration via `/code-create-spec` Extend Mode |
| **Goal tracking** | None | Explicit `goal.md` evaluated each iteration |
| **Best for** | New project, clear spec, one night | Evolving project, growing scope, multi-night |
| **Spec + tickets** | Written by overnight skill itself | Delegated to `/code-create-spec` Extend Mode |

`/code-overnight` is effectively `/code-evolve` with one outer iteration and no goal tracking.

---

## Template-based scaffolding

Shell scripts and agent prompts are pre-written templates stored in `~/.claude/templates/code-evolve/`. The skill copies and substitutes placeholders using `sed` — it never generates these files at runtime. This guarantees consistency across runs and makes scripts independently debuggable.

**Template validation gate:** Before writing any files, the scaffold step checks that the template directory and scripts exist. If they are missing, it prints an explicit error and aborts — it does not attempt to generate the scripts from scratch.

## Env var preflight before launch

Before starting any tmux session, the skill sources `.env` if it exists, then checks every variable listed in `.env.required` is set. If any are missing, it prints a clear list and exits with an error rather than starting a loop that will silently fail mid-run.

```
~/.claude/templates/code-evolve/
  scripts/
    run_outer_loop.sh        ← {SLUG} {PROJECT_DIR} {RUN_NAME} {MAX_ITERATIONS}
    run_build_verify_loop.sh ← generic, no placeholders (shared with /code-overnight)
    post_build.sh            ← {PROJECT_DIR} {RUN_NAME}
    heartbeat.sh             ← {SLUG} {PROJECT_DIR} {RUN_NAME}
  prompts/
    outer_loop_agent.md      ← {RUN_NAME} {PROJECT_DIR}
```

---

## Timing

- Inner loop (build-verify): ~2–3 hours
- Post-build chain: ~30–45 minutes
- **One outer iteration: ~3 hours**
- Max 5 iterations → up to ~15 hours (multi-night capable)

---

## Files created / managed

```
~/Documents/{project-name}/
  prompts/
    goal.md                  ← Phase 1 goal conversation
    app_spec.txt             ← /code-create-spec, appended each iteration
    tickets.md               ← /code-create-spec, append-only across iterations
    outer_loop_agent.md      ← copied from template at scaffold
    spec_update_brief.md     ← outer loop agent writes each iteration
    outer_loop_notes.md      ← outer loop agent writes each iteration
    builder.md               ← /code-build-loop (iteration 1 only)
    verifier.md              ← /code-build-loop (iteration 1 only)
    agent_notes.md           ← builder agent writes each inner cycle
  scripts/
    run_outer_loop.sh        ← copied from template
    run_build_verify_loop.sh ← copied from template
    post_build.sh            ← copied from template
    heartbeat.sh             ← copied from template
    agent-run-logs/
      {slug}-main/           ← same run-name across ALL outer iterations
        loop.log
        outer_loop.log
        build_report.md
        .ticket_progress     ← persists across all iterations
        post-build-logs/
  ui-testing/                ← Playwright screenshots (overwritten each iteration)
  .env
  .env.required
  .gitignore
```

---

## When to use

- You have a working app from `/code-overnight` and want to keep building
- The project scope is too large for one overnight run
- You have a clear long-term goal but not a clear feature list
- You want the system to decide what to build next

## When NOT to use

- You don't have a goal yet → write `goal.md` first (or let the skill's Phase 1 do it)
- The app needs a fundamental architecture change → do that manually first
- You need a specific known feature built → just run `/code-overnight` with a clear spec

---

## Related docs

- [goal-conversation.md](./goal-conversation.md) — how the Phase 1 goal conversation works
- [goal-template.md](./goal-template.md) — the `goal.md` format and static vs. core distinction
- [outer-loop-agent.md](./outer-loop-agent.md) — the agent prompt that drives each iteration
