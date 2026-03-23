# Goal Conversation (Phase 1 of `/code-evolve`)

> This is not a separate skill. It is the first phase of `/code-evolve`, triggered automatically when `goal.md` does not yet exist.

Linked to [[Meta-Loop Skill]] and [[Spec Creation]].

---

## Why goal-setting is part of the skill

A template you fill alone produces shallow goals. The goal is the most important input to the entire build system — it determines what the outer loop iterates on, what "done" looks like, and what gets built vs. skipped.

By making this Phase 1 of `/code-evolve`, you never skip it. The conversation happens once, produces `goal.md`, and then the skill continues to scaffold and loop autonomously.

The conversation challenges you on:
- Are you measuring the right things, or just presence of features?
- What is the one capability that has to be excellent?
- What are you tempted to over-spec that doesn't actually matter?
- Where will a user judge the software in the first 30 seconds?

The output is a `goal.md` you trust enough to hand to an autonomous system.

---

## Conversation structure

The agent leads you through five topics. It debates each one — it will push back on vague criteria and force specificity. You can agree, refine, or override.

### Topic 1 — Purpose and audience
- Who uses this? What is their actual job?
- What problem are they solving when they open the app?
- What does the app need to do in the first 30 seconds to earn their trust?

### Topic 2 — The money-shot
- What is the one capability that makes this software worth building?
- If that capability were mediocre, would the rest of the app matter?
- How would you know if it was excellent vs. just working?
- This becomes the **core refinement target** — what every iteration focuses on

### Topic 3 — Success criteria
- Draft criteria together, then challenge each one:
  - Is this measuring quality or just presence? ("fraud is detected" vs. "3+ contradiction types flagged with correct severity")
  - Is this verifiable by a bash command or a specific UI action? If not, rewrite it.
  - Does this criterion belong to the money-shot, or is it infrastructure?
- End with 5–8 criteria, majority of which are about the core + UI

### Topic 4 — Static vs. core split
- What needs to exist but is not the point? (auth, settings, DB, upload flow)
  → These go in **static components** — built once in iteration 1, not iterated
- What is the real work? (the algorithm, the model output, the decision, the UI moment)
  → These go in **core refinement targets** — what every outer loop iteration focuses on
- What UI moments matter? (where does the user see the value?)
  → These go alongside core as refinement targets

### Topic 5 — Constraints and scope
- What stack / infra / compliance constraints apply?
- What is explicitly out of scope? (name it or the loop will build it)
- How many iterations? (each is ~3 hours; 3 is a full night, 5 is two nights)

---

## Output

A populated `goal.md` written to `~/Documents/{slug}/prompts/goal.md`.

The agent reads it back to you and asks: "Does this accurately represent what you want to build?" One round of edits, then it writes the file.

---

## What the conversation produces in goal.md

```markdown
# Goal — {Project Name}

## Purpose
[2–3 sentences: who uses it, what problem it solves, what earns trust in first 30 seconds]

## The money-shot
[1–2 sentences: the single capability that has to be excellent. Everything else serves this.]

## Core refinement targets
[What the outer loop iterates on — specific, measurable quality targets]
- The {capability}: [what "excellent" looks like, not just "works"]
- The {UI moment}: [what the user should see and feel]

## Static components
[Built once in iteration 1, touched only if broken in later iterations]
- Auth / user management (if any)
- DB schema and migrations
- API scaffold and error handling
- Upload / file handling flow
- Settings / config UI

## Success criteria
[5–8 verifiable criteria, majority focused on core + UI]
- [ ] [Core criterion — specific and measurable]
- [ ] [Core criterion]
- [ ] [UI criterion — tied to a specific user action]
- [ ] [Infrastructure criterion — just needs to exist]
- [ ] [Infrastructure criterion]

## Constraints
- Stack: [e.g. FastAPI + vanilla HTML/JS, SQLite, AWS Bedrock]
- Port: 8000
- [Domain constraints]

## Non-goals
- [Explicit out-of-scope items]

## Max outer loop iterations
[3 = one full night | 5 = two nights]
```

---

## Example conversation excerpt

**Agent:** What is the one capability in this fraud detection demo that has to be excellent? If that part were mediocre, would anything else matter?

**You:** The contradiction detection — finding mismatches across documents.

**Agent:** Okay. "Contradiction detection works" is not a success criterion — that just means it runs. What does excellent look like? Are we talking about catching a specific number of contradiction types? Flagging the right severity? Producing an explanation a claims handler would actually trust?

**You:** It should catch date mismatches, amount mismatches, and identity mismatches. And the explanation should name which documents conflict, not just say "anomaly found".

**Agent:** Good. Draft criterion: "For each of the 5 sample document sets, system identifies at least one date, amount, or identity contradiction and names the specific conflicting documents in the explanation." Is that right?

**You:** Yes, add that severity (LOW/MED/HIGH) must be correct for at least 4/5 cases.

**Agent:** Updated: "...names the specific conflicting documents, with correct severity (LOW/MED/HIGH) on at least 4 of 5 sample sets." That's a real criterion. Moving on.

---

*Created: 19 March 2026*
