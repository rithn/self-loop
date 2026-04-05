# SelfLoop — Autonomous Coding Pipeline

> From spec to shipped, overnight. No human in the loop.

A system that builds production software autonomously — one agent writes, one verifies, ticket by ticket. Iterated across 6 real client projects over 3 months. Autonomy went from 20% to 90%.

---

## The pipeline

```
Spec → Testability Audit → Build Loop (ticket by ticket) → App Testing → UI Testing → HANDOFF
```

Each stage is a Claude Code slash command. Chain them together and the system runs overnight — or across multiple nights — without intervention. Human input is only required at decision points: scope, architecture, blockers.

---

## The autonomy curve

Measured from git commit ratio: autonomous (`Implement TICKET-XXX`) vs. manual fix commits per project.

| Project | Domain | Autonomous commits |
|---------|--------|-----------|
| Large Law Firm — Invoice OCR | Document extraction | ~20% |
| CA Firm — Accounting Automation | CA firm workflows | ~40% |
| Large Law Firm — TP Report Generator | Legal document generation | ~60% |
| Large Insurance Conglomerate — Underwriting Agent | Insurance AI | ~70% |
| InsurTech Startup — Document Fraud Detection | InsurTech | ~90% |

Each project's failure modes were fed back into the pipeline before the next build. The system trains itself on real production feedback.

---

## Skills

### Build pipeline

| Skill | What it does |
|-------|-------------|
| **[/code-create-spec](Spec%20Creation.md)** | Converts a product idea into a full app spec, `plan.md`, and testable ticket list |
| **[/code-testability-audit](Testability%20Audit.md)** | Pre-loop gate — audits tickets for CLI testability, generates `flows.md` + `critical_paths.md`, fixes blockers in-place |
| **[/code-build-loop](Coding%20loops.md)** | Sets up builder + verifier agent prompts and the build-verify loop script; one agent builds, one audits, ticket by ticket |
| **[/code-app-testing](App%20Testing%20Skill.md)** | Generates and runs unit + integration tests from `critical_paths.md` post-build |
| **[/code-ui-testing](UI%20Testing%20Skill.md)** | Playwright-based visual flow tests; screenshots on every meaningful state change |
| **[/code-ui-improve](UI%20Improve%20Skill.md)** | Audits a running app for visual issues; severity-ranked report with fixes |
| **[/code-overnight](Overnight%20Build%20Skill.md)** | Orchestrates the full pipeline — spec → tickets → build loop → tests — in a single overnight run |
| **[/code-claude-md](Claude%20MD%20Scaffold%20Skill.md)** | Recursively writes CLAUDE.md files across a project so every agent has full context at every directory level |

### Meta-loop — multi-night autonomous evolution

| Skill | What it does |
|-------|-------------|
| **[/code-evolve](meta-loop/Meta-Loop%20Skill.md)** | Outer loop: runs up to N build iterations toward a long-term goal; re-specs after each iteration based on test results |
| **[Outer Loop Agent](meta-loop/outer-loop-agent.md)** | The agent prompt driving each outer iteration: syncs spec with reality, assesses progress, writes the next brief |
| **[Goal Conversation](meta-loop/goal-conversation.md)** | Interactive session producing `goal.md` — money-shot, success criteria, static vs. core split |
| **[Goal Template](meta-loop/goal-template.md)** | The `goal.md` format the outer loop evaluates against each iteration |

---

## How the meta-loop works

```
goal.md (long-term goal + success criteria)
        ↓
┌─── OUTER LOOP (up to N iterations, default 5) ──────────┐
│  0. Sync spec with reality (handles manual edits)        │
│  1. Assess: what works, what's missing, what broke       │
│  2. Write spec update brief                              │
│  3. /code-create-spec (Extend Mode) — new tickets        │
│  4. run_build_verify_loop.sh — inner build-verify loop   │
│     ┌─ INNER LOOP ──────────────────────────────────┐   │
│     │  ticket → build → verify → commit → next      │   │
│     └───────────────────────────────────────────────┘   │
│  5. post_build.sh — testability + app tests + UI tests   │
│  6. All success criteria met? → exit. Else → repeat.     │
└──────────────────────────────────────────────────────────┘
```

One outer iteration takes ~3 hours. Five iterations = up to 15 hours of autonomous building.

---

## How it's built

Skills are Claude Code slash commands living in `~/.claude/commands/`. Shell scripts handle orchestration — `run_outer_loop.sh`, `run_build_verify_loop.sh`, `post_build.sh`. All scripts are pre-written templates (see [`templates/`](templates/)), never generated at runtime. The system is composable: run one skill standalone or chain the full pipeline.

---

Built by [Soumya Sharma](https://linkedin.com/in/rithn) — Co-founder, [Livo AI](https://livoassistant.com)
