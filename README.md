# SelfLoop — Autonomous Coding Pipeline

A system for building production software with minimal human intervention. Built and iterated across 6 real client projects over 3 months.

## What it is

A set of composable skills that chain together into a fully autonomous build pipeline:

```
Spec → Testability Audit → Build Loop (ticket by ticket)
→ App Testing → UI Testing → HANDOFF
```

Each skill is a Claude Code slash command. The pipeline runs overnight or across multiple nights without intervention. Human input is only required at decision points — scope, architecture, blockers.

## The autonomy curve

Measured from git commit ratio of autonomous (`Implement TICKET-XXX`) vs manual fix commits per project:

| Project | Domain | Autonomous |
|---------|--------|-----------|
| BCL Invoice OCR | Document extraction | ~20% |
| ASPR Accounting Automation | CA firm workflows | ~40% |
| BCL TP Report Generator | Legal document generation | ~60% |
| ICICI Underwriting Agent | Insurance AI | ~70% |
| Digit Document Fraud Detection | InsurTech | ~90% |

Each project's failure modes were written back into the pipeline before the next build started. The system trains itself on real production feedback.

## The skills

### Build pipeline
- **[Coding loops](Coding%20loops.md)** — the inner build-verify loop: one agent builds, one verifies, ticket by ticket
- **[Spec Creation](Spec%20Creation.md)** — converts a product idea into a full app spec + testable ticket list
- **[Testability Audit](Testability%20Audit.md)** — audits tickets for CLI testability before the loop starts; fixes blockers in-place
- **[App Testing](App%20Testing%20Skill.md)** — generates and runs unit + integration tests post-build
- **[UI Testing](UI%20Testing%20Skill.md)** — Playwright-based visual tests against a running app; screenshots on every state change
- **[UI Improve](UI%20Improve%20Skill.md)** — audits a running app for visual issues; severity-ranked report with fixes
- **[Overnight Build](Overnight%20Build%20Skill.md)** — orchestrates the full pipeline for a single overnight run
- **[Claude MD Scaffold](Claude%20MD%20Scaffold.md)** — recursively writes CLAUDE.md files across a project so agents have context at every level

### Meta-loop (multi-night autonomous evolution)
- **[Meta-Loop / code-evolve](meta-loop/Meta-Loop%20Skill.md)** — outer loop that runs multiple build iterations toward a long-term goal; re-specs after each iteration based on test results
- **[Outer Loop Agent](meta-loop/outer-loop-agent.md)** — the agent prompt that drives each outer iteration: syncs spec with reality, assesses progress, writes the next brief
- **[Goal Conversation](meta-loop/goal-conversation.md)** — interactive session that produces `goal.md`: money-shot, success criteria, static vs. core split
- **[Goal Template](meta-loop/goal-template.md)** — the `goal.md` format that the outer loop evaluates against each iteration

### Other
- **[Ideation](Ideation%20Skill.md)** — structured product ideation grounded in existing client context
- **[Create Deck](Create%20Deck%20Skill.md)** — builds a presentation deck from voice or text, iterates until approved
- **[Video/Audio Cleanup](Video%20Audio%20Cleanup%20Skill.md)** — cleans up raw audio/video recordings

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

## Stack

Skills run as Claude Code slash commands (`~/.claude/commands/`). Shell scripts handle orchestration — `run_outer_loop.sh`, `run_build_verify_loop.sh`, `post_build.sh`. All scripts are pre-written templates, never generated at runtime.

---

Built by [Soumya Sharma](https://linkedin.com/in/rithn) — Co-founder, [Livo AI](https://livoassistant.com)
