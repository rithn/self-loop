# Spec Creation Process

This documents the process for creating a detailed app spec before handing off to autonomous coding agents. We always use **Detailed/Involved Mode** — spending significant time upfront to co-design all technical decisions with the agent.

The output is an `app_spec.txt` (XML) file that autonomous agents use to build the app across multiple sessions.

---

## Context Gathering (First Step)

Before any discussion begins, ask what context is available to seed the spec:

- **Email**: fetch a relevant email thread (via Gmail MCP) — e.g. a client brief, requirements thread, or proposal
- **Obsidian note**: a client note, PRD, or any vault file shared by path
- **Existing `app_spec.txt`** (+ optionally `feature_list.json`): signals that this is a continuation, not a new project
- **Both**: email + a note
- **None**: start from scratch in conversation

If context is provided, the agent reads it first and uses it to pre-fill what it can — then asks only for what's missing or unclear. This replaces the need to re-explain the project from scratch.

**If `app_spec.txt` is provided → Extend Mode.** The agent must:
1. Read the spec to understand what was planned
2. Read `feature_list.json` (if provided) to see what's built vs pending
3. Summarise the current state — what's done, what's still pending from the last spec
4. Ask: are we adding new feature areas, drilling deeper into existing ones, or both?
5. Run only the relevant parts of Feature Discovery for the new chunk
6. Do a focused Technical Deep Dive for the new features only
7. Append to the existing spec and update the feature count

Skip Project Overview, Technology Stack, and any already-covered feature areas.

---

## Project Overview

Start with a conversation — no forms yet.

- Project name
- What is being built (plain English, 2-3 sentences)
- Problem it solves
- Who will use it (just you, team, external users?)

---

## Technology Stack

Decide explicitly (don't use defaults):

- **Frontend**: framework, styling, state management, routing, port
- **Backend**: runtime, framework, port
- **Database**: type + library
- **API style**: REST / GraphQL / tRPC
- **Any external integrations**: APIs, services

---

## Feature Discovery (THE MAIN PHASE)

This is where most time is spent. Cover all areas in conversation:

### Main Experience
- What does a user see when they open the app?
- Walk through a typical user session

### User Accounts
- Do users log in?
- What can they do with their account?
- Auth method: email/password, social, SSO?
- Session timeout? Password requirements?

### What Users Create / Manage
- What "things" do users create, save, or manage?
- Can they edit or delete?
- Can they organize (folders, tags, categories)?

### User Roles & Permissions
- Types of users (just users, users + admins, multiple roles?)
- What can each role see and do?
- Which pages/routes are protected?
- What happens on unauthorized access?
- Any sensitive operations requiring extra confirmation?

### Settings & Customization
- What can users configure?
- Display preferences, themes, notifications?

### Search & Filtering
- What do they search for?
- What filters are useful?
- Sorting options?

### Sharing & Collaboration
- What can be shared?
- View-only or collaborative editing?
- Sharing via link, invite, or permissions?

### Dashboards & Analytics
- Any stats, metrics, or reports the user sees?
- Real-time or historical?

### Domain-Specific Features
- Any features unique to this app/domain not covered above?

### Data Flow & Integration
- What data comes from users vs system-generated?
- Multi-step workflows across pages?
- What happens to related data on deletion (cascade rules)?
- External APIs or imports/exports?

### Error & Edge Cases
- Network failure mid-action?
- Duplicate entries?
- Very long inputs?
- Empty states (no data yet)?

---

## Feature Count

After discovery, the agent tallies discrete testable behaviors:
- Each CRUD op = 1 feature
- Each UI interaction = 1 feature
- Each validation/error case = 1 feature
- Each visual requirement = 1 feature

Agent presents estimate by category → we confirm or adjust → this becomes `feature_count` in the spec.

**Reference tiers**: Simple ~20-50 | Medium ~100 | Advanced ~150-200+

---

## Technical Deep Dive

We co-design each technical area — agent proposes, we review and decide.

### Database Design
- What entities/tables are needed?
- Key fields for each?
- Relationships and foreign keys?
- Indexes, cascade rules?

### API Design
- What endpoints are needed?
- How are they organized (by resource, by feature)?
- RESTful conventions?
- Auth-protected vs public endpoints?

### UI Layout
- Overall structure (sidebar, top nav, main content, modals)
- Key screens/pages
- Navigation flow between screens
- Design preferences (color palette, typography, theme)

### Implementation Phases
- What order do we build things?
- What are the dependencies?
- What's in Phase 1 (foundation) vs later phases?

### Testability Gate

Before approving the spec, explicitly verify:

- What are the distinct user flows in this app?
- For each flow: can it be fully exercised via CLI, curl, pytest, or MCP — with **no browser required**?
- If any flow is browser-only (e.g. UI-only interaction with no API backing it), the architecture must change before proceeding.

The rule: **if a flow can't be triggered and verified from the terminal, it can't be verified by the build loop.** Every flow needs a CLI-reachable entry point — an API endpoint, a CLI command, a script, or an MCP tool.

If gaps are found, resolve them now: add an API endpoint, expose a CLI entrypoint, or restructure the feature so it has a testable backend path.

---

## Success Criteria

Define what "done" looks like:

- Must-have functionality (MVP)
- Quality expectations (polished UI vs just functional)
- Performance requirements
- Any specific hard requirements

---

## Review & Approval

Agent presents full summary:
1. App description (plain language)
2. Feature count (by category)
3. Tech stack chosen
4. DB schema overview
5. API structure overview
6. UI layout summary
7. Implementation phases

We review, request changes if needed, then give final approval.

---

## Output Files

Generated in `generations/{project_name}/`:

| File | Purpose |
|------|---------|
| `app_spec.txt` | Full XML spec — source of truth for all agents |
| `tickets.md` | Ordered engineering tickets derived from the spec |

---

## Ticket Generation (Final Step)

After the spec is approved, generate `tickets.md`. This replaces the old initializer prompt — tickets are the unit of work for coding agents.

### What a ticket contains

```
### TICKET-XXX: <Title>

**Depends On:** TICKET-YYY, TICKET-ZZZ (or None)

**Scope:**
Plain-language description of exactly what this ticket builds. What behaviour or capability exists when this ticket is done.

**Verification:**
```bash
# Shell commands that prove this ticket is done
# Expected output on each line as a comment
```
```

### Rules for generating tickets

1. **One concern per ticket** — a ticket covers one module, one endpoint group, one UI section, or one test suite. Never bundle unrelated things.
2. **Explicit dependencies** — list every ticket that must be done first. If none, say `None`.
3. **Ordered by dependency** — tickets must be sequenceable top-to-bottom. The first ticket is always the project skeleton / directory setup.
4. **Scope describes intent, not implementation** — say what the ticket achieves and what constraints matter (e.g. business rules, data shapes from the spec). Leave file choices and code structure to the agent.
5. **Every ticket has a verification block** — a concrete bash or test command that returns a deterministic pass/fail. The agent runs this after implementing to confirm correctness.
6. **Phases map to ticket ranges** — if the spec has Implementation Phases, group tickets accordingly with a phase header comment in the file.

### Ticket file structure

```markdown
# {Project Name} — Engineering Tickets

## Architecture Reference
(copy the tech stack table from the spec)

## Target Directory Layout
(copy the directory tree from the spec)

---

### TICKET-001: Project Skeleton
...

### TICKET-002: ...
...
```

### After generating tickets

Hand the `tickets.md` file to a coding agent. The agent works through tickets in order, implementing each one, running the verification block, and committing before moving to the next.
