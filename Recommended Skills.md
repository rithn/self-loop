# Recommended Skills & Workflow Gaps

> Updated: 13 March 2026. Full gap analysis of what is preventing the AI-does-the-heavy-lifting vision from working smoothly.

---

## Core Diagnosis: Skills Exist, Workflows Don't

Skills are tools you pick up manually. Workflows fire automatically at the right moment with the right context and put output in the right place. That gap is what's preventing this from running smoothly.

---

## Gap 1: No Daily Rhythm Automation *(Highest Priority)*

**What's missing:** `plan-standup`, `plan-briefing`, `plan-calendar` all exist but must be manually invoked each morning. The "Morning briefing cron" and "Calendar blocking agent" are both listed as Planned in `connected-systems.md` and haven't been built.

**What's needed:** A morning cron that fires automatically at 8am → pulls Gmail + Calendar + Obsidian → generates briefing + blocks calendar + surfaces today's priorities. You shouldn't be starting the day by opening Claude and typing a command.

**Skill to build:** `/morning-brief` (cron-triggered, no manual invocation needed)

---

## Gap 2: Social Media Has No Pipeline

**What's missing:**
- Skills exist for LinkedIn ideas and drafts only
- No Twitter or Instagram equivalents
- No content calendar (2-week queue of drafts)
- No clear "draft → where does it live for review → post" workflow
- Done day-by-day when it should be batch-created weekly

**What's needed:** A weekly content batch skill that produces 7 LinkedIn posts + 14 tweets + 7 Instagram captions in one session, saved to a dated queue in `socials/`, ready to copy-paste.

**Skill to build:** `/create-content-week` — batch content creation for all channels

---

## Gap 3: HubSpot is Connected But Not Maintained

**What's missing:** CRM connection exists but nothing pushes client meeting notes or deal stage changes from vault to HubSpot. The CRM is likely weeks out of date.

**What's needed:** After each standup update, auto-log key client interactions and deal stage changes to HubSpot. Could be a hook inside `/plan-standup` rather than a separate skill.

**Skill to build:** Add HubSpot sync step to `/plan-standup` — after generating standup, extract client updates and log them to CRM.

---

## Gap 4: No New Lead Intake Workflow

**What's missing:** Primary growth channel is personal contacts but there is no defined workflow for: "I met someone relevant" → create client file → add to HubSpot → draft intro/follow-up email → set calendar reminder. `enrich-client` covers one piece but the 4-step flow isn't connected end to end.

**What's needed:** A single skill that takes a name and context and does the full intake: research → client file → CRM → draft email → calendar reminder.

**Skill to build:** `/intake-lead [name]` — full new contact intake flow

---

## Gap 5: Email Triage Has No Intake Side

**What's missing:** `/comms-reply-email` handles replies. But there is no skill for: scan inbox → identify actionable emails from clients and leads → extract tasks → add to today's vault note.

**What's needed:** A morning email triage step (could be part of morning brief cron) that reads recent unread emails and surfaces: what needs a reply, what needs a task, what's just FYI.

**Skill to build:** Add email triage to `/morning-brief` or build `/triage-inbox` as standalone

---

## Gap 6: No Meeting Prep Skill

**What's missing:** Before calls with clients (Shonak, Rakesh, ICICI, etc.) context must be manually pulled together. No skill exists to: pull client file + recent emails + open action items + goals for the call → produce a 1-page brief.

**What's needed:** A skill that takes a person's name, finds their client file, searches Gmail for recent threads, checks open tasks in the vault, and produces a pre-call brief.

**Skill to build:** `/prep-meeting [person]` — pre-call brief generated 30 mins before

---

## Gap 7: Context Graph — The Deepest Missing Piece

**What's missing:** Context Graph is the internal product that would power this entire setup. Without it, every session requires manually maintained vault files to give Claude context. Once Context Graph ingests Gmail + Obsidian + HubSpot → Claude enters every session with full institutional memory automatically. This is own dog food and it is not built yet.

**What's needed:** Build it. Start with Gmail ingestion → entities (people, companies, projects, decisions) → Neo4j graph → Claude reads graph at session start.

**This is a product project, not a skill.**

---

## Priority Build Order

| Priority | What to Build | Effort | Impact |
|---|---|---|---|
| 1 | Morning briefing cron (`/morning-brief`) | Low — 1 skill + cron | High — starts every day right |
| 2 | Meeting prep skill (`/prep-meeting`) | Low — 1 skill | High — directly supports client work |
| 3 | HubSpot sync inside `/plan-standup` | Low — extend existing skill | High — CRM becomes useful |
| 4 | New lead intake (`/intake-lead`) | Medium — multi-step skill | High — core growth motion |
| 5 | Weekly content batch (`/create-content-week`) | Medium | Medium — consistency at scale |
| 6 | Email triage inside morning brief | Medium | Medium — reduces mental overhead |
| 7 | Context Graph (own dog food) | High — full project build | Transformative — long term |

---

## Already Built (as of March 2026)

- `/plan-standup` ✅
- `/plan-briefing` ✅
- `/plan-calendar` ✅
- `/plan-enrich-client` ✅
- `/comms-reply-email` ✅
- `/create-linkedin-ideas` ✅
- `/create-linkedin-draft` ✅
- `/create-deck` ✅
- `/create-clean-audio` ✅
- `code-build-loop`, `code-app-testing`, `code-testability-audit`, `code-ui-testing`, `code-ui-improve` ✅
- `/vault-sync` ✅ — vault consistency audit (projects ↔ clients, daily tasks, skills, carry-forwards)
- `/code-overnight` ✅ — autonomous overnight demo builder: spec + atomic tickets + build loop + heartbeat + post-build testing chain
