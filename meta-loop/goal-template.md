# goal.md — Template

> Ideally, produce this file by running `/plan-goal` rather than filling it manually.
> The conversation challenges your criteria and ensures the money-shot is well-defined.
> If filling manually, use this template.

---

```markdown
# Goal — {Project Name}

## Purpose
[2–3 sentences: who uses this, what problem it solves, what earns their trust in the first 30 seconds]

## The money-shot
[1–2 sentences: the single capability that has to be excellent.
If this were mediocre, nothing else in the app would matter.
Examples: retrieval accuracy in a search agent; the underwriting decision in an underwriting tool;
contradiction detection in a fraud demo; the P&L classification in an accounting tool.]

## Core refinement targets
What the outer loop iterates on. These are the things that need to get better with each cycle.

- The {core capability}: [what "excellent" looks like — specific and measurable, not just "works"]
- The {key UI moment}: [what the user should see/feel at the critical screen]
- [Add 1–2 more if needed — keep it focused]

## Static components
Built once in iteration 1. The outer loop does NOT write tickets for these unless they are broken.

- [ ] Auth / user management (if any)
- [ ] DB schema and migrations
- [ ] API scaffold, error handling, startup
- [ ] File upload / storage flow
- [ ] Settings / config UI (if any)
- [Add any project-specific one-time components]

## Success criteria
5–8 verifiable criteria. The majority should be about core + UI quality, not just "feature exists".
Bad: "Fraud detection works"
Good: "For each of the 5 sample document sets, system identifies at least one date, amount, or
identity contradiction and names the specific conflicting documents, with correct severity on 4/5 sets"

- [ ] [Core criterion — specific and measurable]
- [ ] [Core criterion]
- [ ] [UI criterion — tied to a specific user action or screen]
- [ ] [Infrastructure criterion — just needs to exist and not break]
- [ ] [Infrastructure criterion]

## Constraints
Hard rules the outer loop must never violate when updating the spec:

- Stack: FastAPI + vanilla HTML/JS, SQLite, AWS Bedrock
- Port: 8000
- No auth (demo) / Auth via Supabase (production)
- [Domain constraints — e.g. "India region only (ap-south-1)", "amounts in AED", "no external APIs except AWS"]

## Non-goals
Explicitly out of scope — name these or the loop will build them.

- [e.g. "No user accounts or login"]
- [e.g. "No mobile layout"]
- [e.g. "No real data — synthetic samples only"]
- [e.g. "No integration with client systems"]

## Max outer loop iterations
3   ← one full night (~9 hours)
5   ← two nights (~15 hours)
```

---

## When to write goal.md

- **New project:** write (or generate via `/plan-goal`) before running `/code-evolve` — the scaffold step uses it to generate the initial `app_spec.txt`
- **Existing project:** write alongside the existing codebase — the spec sync step (step 0 of the outer loop) will reconcile what's already built against the criteria before planning the next iteration

---

## How the outer loop agent uses this file

1. **Reads it at the start of every outer loop iteration** — before syncing spec or assessing progress
2. **Evaluates each success criterion** against test results and app behavior
3. **Stops early** if all criteria are checked off
4. **Focuses spec deltas on core refinement targets** — not static components
5. **Ignores static components** when writing new tickets (unless a test is failing for one)
6. **Stays within constraints** — never violates them in spec deltas
7. **Ignores non-goals** — never proposes features listed there

---

## The static vs. core distinction

This is the most important design decision in `goal.md`.

**Static components** are the scaffolding — they need to exist and not break, but they do not make the software valuable. Auth, file upload, DB schema, settings — these are table stakes. The outer loop builds them in iteration 1 and moves on.

**Core refinement targets** are the reason the software exists. A search agent's value is retrieval accuracy. An underwriting tool's value is the quality of the underwriting decision. A fraud demo's value is the credibility of the contradiction detection. These are what every subsequent iteration should improve.

If your success criteria are mostly about static components ("user can log in", "file uploads work"), you have the wrong criteria. Rewrite them to measure the core.

---

## Example (fraud detection demo)

```markdown
# Goal — Document Fraud Detection Demo

## Purpose
An insurance claims handler uploads a set of claim documents (ID proof, medical reports,
invoices) and gets an AI-generated consistency report flagging contradictions and anomalies.
Used to demo Livo AI's fraud detection capability to Go Digit at the 25 Mar meeting.
Earns trust in 30 seconds by showing a real contradiction with a clear explanation.

## The money-shot
The contradiction detection — finding inconsistencies across documents and explaining
exactly which documents conflict and why. If this output were vague or wrong, the demo fails.

## Core refinement targets
- Contradiction detection: catches date mismatches, amount mismatches, and identity mismatches;
  names the specific conflicting documents; correct severity (LOW/MED/HIGH) on 4/5 sample sets
- Results UI: findings are scannable in under 10 seconds; risk level is visually immediate;
  each finding links to the source documents

## Static components
- [ ] SQLite DB schema and migrations
- [ ] FastAPI app scaffold + startup
- [ ] File upload endpoint + local storage
- [ ] Upload history table (read-only)

## Success criteria
- [ ] User can upload 2–5 documents via drag-and-drop
- [ ] System detects and displays at least 3 contradiction types (date, amount, identity)
- [ ] Each finding names the specific conflicting documents
- [ ] Severity (LOW/MED/HIGH) is correct on at least 4 of 5 sample sets
- [ ] Summary risk score shown at top of results page
- [ ] Results page is scannable in under 10 seconds (judge from UI screenshot)
- [ ] All 5 sample document sets produce non-empty, meaningful output

## Constraints
- Stack: FastAPI + vanilla HTML/JS, SQLite, AWS Bedrock
- Port: 8000
- No auth
- AWS ap-south-1 only

## Non-goals
- No real claim documents — synthetic samples only
- No Go Digit system integration
- No mobile layout

## Max outer loop iterations
3
```
