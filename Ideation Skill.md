# Ideation Skill (`/plan-ideate`)

This skill runs before app spec creation, for situations where you know the client and domain but haven't yet decided what to build. It uses a **branching-narrowing framework** — diverge first (research → ideas), then converge (score → select) — and supports multiple rounds of depth.

The output is a product brief saved to `product_briefs/` in the current working directory. This brief is the direct input to `/code-create-spec`.

---

## When to Use

Use this skill when:
- You're about to build something for a client but haven't locked down the product direction
- You want to explore what's most valuable to build before committing to a spec
- A client meeting has surfaced multiple possible directions and you need to evaluate them

Do not use this skill if you already know what you're building — go straight to `/code-create-spec`.

---

## Intake (Step 1)

The skill asks upfront before doing anything:

1. **Who is the client?** (used to pull vault context)
2. **What research directions should I pursue?**
   - e.g. "Search for AI use cases in pharma QA document management, look at Encube's recent news, find any industry reports on AI in CDMO manufacturing"
   - This keeps research focused. The skill does not decide what to search for.
3. **Any constraints to keep in mind?**
   - e.g. "Must be demoable in 4–6 weeks", "Must use existing Enterprise Search stack", "Client wants something in their QA department"

The skill does not proceed until all three are answered.

---

## Research Phase (Step 2)

Runs in parallel:

**Vault research:**
- Reads `Clients & Partners/[Client].md`
- Searches email history for the client (sent + received) — extracts pain points, requests, complaints, aspirations mentioned in threads
- Reads any linked project file from `projects.md`

**Web research:**
- Runs web searches based on the directions given in intake
- Searches for: industry challenges, competitor products, analyst reports, recent news about the client or their sector
- Summarises findings compactly — no raw dumps

The skill presents a **Research Summary** before generating ideas: key pain points found, relevant industry context, any notable constraints or opportunities surfaced. This is a checkpoint — you can correct or add context before ideas are generated.

---

## Round 1 — Wide Idea Generation (Step 3)

From the research, the skill generates **10–15 ideas**. Each idea is one sentence: what it is and what problem it solves for the client.

Ideas should span the full space — don't cluster around one theme. If research surfaces 3 distinct problem areas, ideas should cover all three.

---

## Round 1 — Scoring (Step 4)

Each idea is scored on three dimensions, 1–5:

| Dimension | What it means |
|-----------|---------------|
| **Alignment** | How well it connects to Livo AI's existing products and tech stack (Enterprise Search, Geospatial Agents, Context Graph) |
| **Demoability** | Can a working demo be built and shown in 4–6 weeks? This is a soft filter — anything scoring 1 should be flagged as likely out of scope |
| **Client impact** | How much does this move the needle for the client? Is this a top-3 pain point or a nice-to-have? |

Scores are presented as a table. The skill does **not** recommend a selection — you decide.

---

## Round 1 — Selection (Step 5)

You pick 2–3 ideas to carry forward.

After selection, the skill asks:

> "Want to stop here and generate the product brief, or go deeper on any of these ideas first? If deeper, which ones — and any specific angles to explore?"

---

## Round 2 — Deep Exploration (Optional, Step 6)

Triggered only if you ask for it, and only for the ideas you specify.

You tell the skill which ideas to explore deeper and what angles to investigate. Example: "Go deeper on fraud detection — specifically fake image submissions and network fraud patterns."

For each idea you've chosen to explore:
- The skill runs more targeted web searches on the specific angle
- Generates 8–10 sub-ideas or implementation variants within that idea
- Scores them on the same three dimensions
- Presents a scoring table per idea

You then select 1–2 per idea to carry into the brief.

You can run Round 2 on one selected idea, some, or all — your choice each time.

Round 2 can repeat if needed (e.g. you narrow from fraud → fake images → a specific detection approach). Each round uses the same pattern: targeted intake → research → ideas → scoring → selection → stop or go deeper.

---

## Product Brief (Final Step)

Written after whichever round you stop at. Saved to `product_briefs/[Client] — [date].md` in the current working directory.

### Structure

```
# Product Brief — [Client] — [Date]

## Research Summary
Key findings from vault + web research that shaped the ideas.

## All Ideas Explored

### Round 1
| # | Idea | Alignment | Demoability | Client Impact | Notes |
|---|------|-----------|-------------|---------------|-------|
...

### Round 2 — [Idea Name] (if applicable)
| # | Variant | Alignment | Demoability | Client Impact | Notes |
...

## Selected Ideas

### [Idea 1 Name]
- **What it is:** one paragraph
- **Problem it solves:**
- **Why selected:** score rationale + strategic fit
- **Why not others:** brief note on what was ruled out

### [Idea 2 Name]
...

## Suggested Next Step
Hand this brief to `/code-create-spec` to define the product fully.
```

---

## Output Location

`product_briefs/[Client] — [YYYY-MM-DD].md` in the current working directory (i.e. wherever the skill is invoked from).

If `product_briefs/` does not exist, create it.

---

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `/code-create-spec` | Downstream — the product brief is the input |
| `/plan-enrich-client` | Complementary — run this first if the client file is thin |
| `/plan-standup` | Upstream — ideation tasks surface here as carry-forwards |
