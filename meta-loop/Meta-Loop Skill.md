# Meta-Loop Skill (`/code-evolve`)

> Type `/code-evolve [project idea or slug]` to autonomously evolve a software project towards a long-term goal — running multiple build-test-assess cycles overnight without intervention.

Linked to [[Overnight Build Skill]] and [[Coding loops]].

---

## What it does

Takes a project idea and runs the full pipeline — from goal setting to working, tested app — autonomously. Goal setting is the first phase of the skill, not a separate step.

**Phase 1 — Goal setting** (if `goal.md` doesn't exist yet):
Interactive conversation that produces `goal.md` — the money-shot, success criteria, static vs. core split, constraints. See [[goal-conversation]] for how this works.

**Phase 2 — Outer loop** (runs up to N iterations):
Each iteration delegates to skills that already exist — the skill adds only the assessment and goal-tracking layer on top.

1. **Syncs spec with reality** — reconciles `app_spec.txt` against actual code (handles manual edits between iterations)
2. **Assesses against goal** — what's working, what's missing, what broke
3. **Writes a brief** → hands off to `/code-create-spec` (Extend Mode) to update spec + tickets
4. **Runs the inner build-verify loop** — same `run_build_verify_loop.sh` used by `/code-overnight`
5. **Runs post-build chain** — `post_build.sh` → testability audit + app testing + UI testing
6. **Checks goal completion** — exits if done, else repeats up to max iterations

The outer loop agent itself does **not** write spec sections or tickets — it assesses and directs. All spec/ticket work goes through `/code-create-spec`.

---

## How it differs from `/code-overnight`

| | `/code-overnight` | `/code-evolve` |
|---|---|---|
| **Runs** | Once | Up to N outer loop iterations |
| **Spec** | Written once at start | Updated each iteration via `/code-create-spec` Extend Mode |
| **Goal tracking** | None | Explicit `goal.md` evaluated each iteration |
| **Best for** | New project, clear spec, one night | Evolving project, growing scope, multi-night |
| **Scaffolds project** | Yes (always) | Yes (iteration 1 only) |
| **Inner loop** | `run_build_verify_loop.sh` | Same |
| **Post-build** | `post_build.sh` | Same |
| **Spec + tickets** | Written by overnight skill itself | Delegated to `/code-create-spec` Extend Mode |

`/code-overnight` is effectively `/code-evolve` with `--max-outer-loops 1` and no goal tracking.

## Global file structure

Shell scripts and agent prompts are **pre-written templates** — never generated at runtime. The skill copies and substitutes placeholders using `sed`. This guarantees consistency across runs and makes scripts independently debuggable.

```
~/.claude/
  commands/
    code-evolve.md                  ← skill command (Claude reads this on /code-evolve)
  templates/
    code-evolve/
      scripts/
        run_outer_loop.sh           ← {SLUG} {PROJECT_DIR} {RUN_NAME} {MAX_ITERATIONS}
        run_build_verify_loop.sh    ← generic, no placeholders (shared with /code-overnight)
        post_build.sh               ← {PROJECT_DIR} {RUN_NAME}
        heartbeat.sh                ← {SLUG} {PROJECT_DIR} {RUN_NAME}
      prompts/
        outer_loop_agent.md         ← {RUN_NAME} {PROJECT_DIR}
```

The vault docs in `self-loop/meta-loop/` are **reference documentation only** — they document the design but are never read at runtime.

---

## Skill reuse map

| Step | Skill used | New or existing |
|---|---|---|
| Goal conversation (if no goal.md) | built into `/code-evolve` | New |
| Initial scaffold | same steps as `/code-overnight` | Existing |
| Spec sync + assessment | outer loop agent | New (thin layer) |
| Spec update + tickets | `/code-create-spec` Extend Mode | Existing |
| Builder/verifier setup | `/code-build-loop` (iteration 1) / ticket carry-over (2+) | Existing |
| Inner build loop | `run_build_verify_loop.sh` | Existing |
| Testability audit | `/code-testability-audit` via `post_build.sh` | Existing |
| App testing | `/code-app-testing` via `post_build.sh` | Existing |
| UI testing | `/code-ui-testing` via `post_build.sh` | Existing |
| Outer orchestration | `run_outer_loop.sh` | New |

---

## Entry scenarios

The skill checks two things on startup: does `goal.md` exist? Does the project directory exist?

### Scenario A — Brand new (no goal.md, no directory)
```
/code-evolve [idea]
    ↓
Goal conversation → produces prompts/goal.md
    ↓
Scaffold:
  mkdir {project-dir}/{prompts,scripts,scripts/agent-run-logs}
  copy AWS creds → .env
  copy + substitute ~/.claude/templates/code-evolve/scripts/* → scripts/
  copy + substitute ~/.claude/templates/code-evolve/prompts/* → prompts/
  git init
    ↓
Outer loop → iteration 1 → inner loop → post-build → assess → ...
```

### Scenario B — Goal written, project not yet built
```
/code-evolve [slug]   (goal.md already in prompts/)
    ↓
Skip goal conversation
    ↓
Scaffold: (same as Scenario A, minus goal conversation)
    ↓
Outer loop → iteration 1 → inner loop → post-build → assess → ...
```

### Scenario C — Resuming an existing project
```
/code-evolve [slug]   (goal.md + project directory both exist)
    ↓
Skip goal conversation, skip scaffold
    ↓
Outer loop → spec sync → assess → inner loop → post-build → assess → ...
```

---

## Full loop diagram

```
goal.md (long-term goal + constraints + success checklist)
        ↓
[Scaffold if new project — runs once only]
        ↓
┌─── OUTER LOOP (max N, default 5) ───────────────────────────┐
│                                                              │
│  0. Sync spec with reality                                   │
│     read git log + CLAUDE.md + file structure                │
│     reconcile app_spec.txt with what is actually built       │
│     (handles manual edits made between iterations)           │
│                                                              │
│  1. Read goal.md + synced app_spec.txt + last test results   │
│     + UI screenshots + outer_loop_notes.md                   │
│  2. Assess: what works, what's missing, what needs changing  │
│  3. `/code-create-spec` Extend Mode                          │
│     → update app_spec.txt + write new tickets.md             │
│  4. `/code-build-loop`                                       │
│     → refresh builder.md/verifier.md (iter 1)               │
│     → carry over completed tickets from last run (iter 2+)   │
│  5. `run_build_verify_loop.sh` — inner build-verify loop     │
│                                                              │
│     ┌─ INNER LOOP ──────────────────────────────┐           │
│     │  ticket → build → verify → commit → next  │           │
│     │  (until .done sentinel)                   │           │
│     └───────────────────────────────────────────┘           │
│                                                              │
│  6. `post_build.sh`                                          │
│     ├─ `/code-testability-audit` (fix blockers in-place)     │
│     ├─ `/code-app-testing` (unit + integration)              │
│     └─ `/code-ui-testing` (Playwright screenshots)           │
│                                                              │
│  7. Read test results + UI screenshots                       │
│  8. All success criteria met in goal.md? → exit              │
│  9. Outer loop count < max? → go to step 0                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
        ↓
   Final report: iterations completed, goal checklist status,
   test pass/fail, UI screenshots
```

### Why step 0 (spec sync) matters

`app_spec.txt` is the **intended** state. The actual code is the **real** state. These drift when:
- Manual fixes were applied directly to the code between iterations
- The builder implemented something slightly differently from the spec
- New constraints or edge cases were discovered mid-build

Without syncing first, the outer loop agent would propose a delta on top of a stale spec — potentially re-adding things already built or overwriting things that changed. Step 0 closes that gap before any new planning happens.

---

## Timing

- Inner loop (build-verify): ~2–3 hours
- Post-build chain: ~30–45 min
- **One outer loop iteration: ~3 hours**
- Max 5 iterations → up to ~15 hours (multi-night capable)

---

## Files it creates / manages

Origin of each file shown: **[template]** = copied from `~/.claude/templates/code-evolve/` | **[generated]** = written by a skill at runtime | **[runtime]** = created by the running process

```
~/Documents/{project-name}/
  prompts/
    goal.md                  ← [generated] Phase 1 goal conversation
    app_spec.txt             ← [generated] /code-create-spec, appended each iteration
    tickets.md               ← [generated] /code-create-spec, append-only across iterations
    outer_loop_agent.md      ← [template]  copied + placeholders substituted at scaffold
    spec_update_brief.md     ← [runtime]   outer loop agent writes this each iteration
    outer_loop_notes.md      ← [runtime]   outer loop agent writes this each iteration
    builder.md               ← [generated] /code-build-loop (iteration 1 only)
    verifier.md              ← [generated] /code-build-loop (iteration 1 only)
    agent_notes.md           ← [runtime]   builder agent writes this each inner cycle
  scripts/
    run_outer_loop.sh        ← [template]  copied + placeholders substituted at scaffold
    run_build_verify_loop.sh ← [template]  copied as-is (generic, no placeholders)
    post_build.sh            ← [template]  copied + placeholders substituted at scaffold
    heartbeat.sh             ← [template]  copied + placeholders substituted at scaffold
    agent-run-logs/
      {slug}-main/           ← same run-name across ALL outer iterations
        loop.log             ← [runtime]
        outer_loop.log       ← [runtime]
        build_report.md      ← [runtime]
        .ticket_progress     ← [runtime]   persists across all iterations
        .done                ← [runtime]   deleted before each new iteration
        post-build-logs/     ← [runtime]
  ui-testing/                ← [runtime]   Playwright screenshots, overwritten each iteration
  .env
  .env.required
  .gitignore
```

---

## Autonomous decisions

The outer loop agent makes all of these without asking:

| Decision | How it decides |
|----------|---------------|
| Spec delta scope | Only add/change what the test results and goal gap justify — never rewrite working sections |
| Ticket count per iteration | 10–20 (smaller than a full overnight build — focused improvements) |
| When to stop early | All success criteria in `goal.md` are checked off |
| What to fix vs. what to add | Failing tests → fix first; all tests pass → add next feature |
| Regressions | If a previously passing test fails, prioritise fix ticket before new features |

---

## When to use

- You have a working app from `/code-overnight` and want to keep building
- The project scope is too large for one overnight run
- You want the system to decide what to build next, not you
- You have a clear long-term goal but not a clear feature list

## When NOT to use

- You don't have a goal yet → write `goal.md` first
- The app needs a fundamental architecture change → do that manually, then use this
- You need a specific feature built → just run `/code-overnight` with a clear spec

---

## Key files to understand

- [[goal-conversation]] — why `/plan-goal` exists and how the conversation works
- [[goal-template]] — the format of `goal.md` and the static vs. core distinction
- [[outer-loop-agent]] — the agent prompt that drives the outer loop

---

*Created: 19 March 2026*
