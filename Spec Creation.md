# Spec Creation (`/code-create-spec`)

> Type `/code-create-spec` to co-design an app spec through a structured conversation, then generate `app_spec.txt`, `tickets.md`, and `prompts/plan.md` ready for the build loop.

---

## What it does

Deeply understands what is being built by working through every design decision with you in conversation — never silently deriving choices. Produces a detailed `app_spec.txt` (XML) and `tickets.md` that autonomous coding agents use across multiple sessions.

All output files go to a `prompts/` folder in the current working directory.

---

## Modes

**New project:** Works through all phases below to produce the full spec from scratch.

**Extend Mode (triggered if you provide an existing `app_spec.txt`):** The skill reads the current spec plus the most recent build logs and ticket progress, reconciles what is planned vs. what is actually built, summarises the gap, then runs only the relevant phases for the new chunk. On approval, it appends to the existing spec and ticket files — never replaces them.

---

## Phase 1 — Context gathering (blocking gate)

Before anything else, the skill asks for every source to read first:
- Email threads (Gmail search)
- File attachments (Excel, PDF, images — reads them directly)
- Diagrams or screenshots
- Obsidian notes
- An existing `app_spec.txt` (triggers Extend Mode)

Each source is read and confirmed with a checklist before moving on. If attachments are mentioned but no path is given, the skill stops and asks for it — it does not proceed on assumptions.

---

## Phase 2 — Project overview

Project name, what is being built in plain language, who will use it.

---

## Phase 3 — Technology stack

Every stack choice is made explicitly — framework, styling, state management, routing, port, backend runtime, database, API style, external integrations. No defaults are assumed without asking.

---

## Phase 4 — Feature discovery

The main phase. Covers every feature area in conversation:

- Main user experience
- User accounts and authentication
- What users create and manage
- Roles and permissions (including protected routes)
- Settings and customisation
- Search and filtering
- Sharing and collaboration
- Dashboards and analytics
- Domain-specific features
- Data flow and integration
- Error and edge cases

**Data features gate:** For any feature that processes structured files (CSV, Excel, PDF), the skill asks for a sample file, reads it directly, notes exact column names and header row positions, and confirms understanding before continuing. Column mappings are never assumed from descriptions alone.

---

## Phase 4L — Feature count

After discovery, the skill tallies discrete testable behaviours (each CRUD op, UI interaction, validation case, and visual requirement counts as 1). Presents the estimate by category, waits for confirmation, and this number becomes `feature_count` in the spec.

Reference tiers: Simple ~20–50 | Medium ~100 | Advanced ~150–200+

---

## Phase 5 — Technical deep dive

Co-designs each area with you — proposes, you confirm or adjust:

- Database schema (tables, fields, relationships, indexes, cascade rules)
- API design (endpoints, auth-protected vs public)
- UI layout (structure, key screens, navigation flow, design preferences)
- Implementation phases and build order

**Testability gate:** Before approving, the skill runs through every user flow and asks whether it can be fully triggered and verified via CLI, curl, pytest, or MCP with no browser required. Any browser-only flow must be resolved with an architectural fix (adding an API endpoint, exposing a CLI entrypoint) before the spec is approved.

---

## Phase 5.5 — Intermediate plan

Before generating `app_spec.txt` or `tickets.md`, the skill writes `prompts/plan.md` — a plain-language document capturing the business logic for each feature: what it does, inputs, processing steps (including exact formula values), edge cases, and output shapes.

This file becomes the authoritative reference for builder and verifier agents. It is shown to you and must be explicitly confirmed before file generation proceeds.

---

## Phase 6 — Success criteria

Defines what "done" looks like: must-have functionality, quality bar, performance requirements, hard constraints.

---

## Phase 7 — Review and approval

Full summary presented: app description, feature count by category, tech stack, DB schema overview, API structure, UI layout, implementation phases. Final confirmation before files are written.

---

## Output files

Generated in `prompts/`:

| File | Contents |
|---|---|
| `app_spec.txt` | Full XML spec — source of truth for all agents |
| `tickets.md` | Ordered engineering tickets derived from the spec |
| `plan.md` | Business logic reference — exact algorithms, edge cases, data formats |

---

## Ticket generation rules

1. **One concern per ticket** — one module, one endpoint group, one UI section, or one test suite
2. **Atomic scope** — smallest independently deployable and verifiable unit; prefer 4 small tickets over 1 large one
3. **Explicit dependencies** — every ticket lists what must be done first; if none, says `None`
4. **Ordered by dependency** — sequenceable top-to-bottom; first ticket is always the project skeleton
5. **Scope describes intent, not implementation** — states what the ticket achieves and what constraints matter; leaves code structure to the agent
6. **Every ticket has a verification block** — a concrete bash or test command with a deterministic pass/fail
7. **Service / Router / Frontend are always separate tickets** — for any feature touching all three layers, minimum 3 tickets
8. **Business rules reference plan.md** — each ticket scope says "See `prompts/plan.md` — [Feature Name] section" rather than re-copying logic inline

### Ticket format

```
### TICKET-NNN: Title

**Depends On:** TICKET-XXX (or None)

**Scope:**
[What this ticket achieves. Constraints from the spec that matter. Reference plan.md for business rules.]

**Verification:**
```bash
# Shell or test command that proves this ticket is done
# Expected: [exact expected output]
```
```

After generating tickets, the skill reconciles against `app_spec.txt` — confirms every endpoint has a ticket, and every ticket references only files and endpoints that exist in the spec.
