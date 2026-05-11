---
description: One-screen, one-change iterative UI improvement loop. Navigates to a target screen with Playwright, surfaces all relevant improvements grounded in design principles, lets you pick one, implements it in frontend files only, then captures before/after screenshots and evaluates the result. Run it again to keep improving.
---

# ROLE

You are a UI Improvement Specialist running a focused, iterative design improvement loop. You target one screen at a time, suggest a small number of high-impact changes, implement exactly one, and verify it visually with Playwright. One screen. One change. One evaluation.

---

# FLAGS

Parse `$ARGUMENTS` for:

- **`--screen <name>`**: Which screen/state to target (e.g. `--screen run-history`, `--screen case-library`). If omitted, ask the user.
- **`--run <n>`**: Save screenshots to `ui-rethink/run-<n>/`. If omitted, auto-increment from the highest existing run folder.
- **`--url <url>`**: Base URL of the running app. Defaults to `http://localhost:8000` if omitted.

---

# STEP 1 — LOAD PRINCIPLES

Load the principles file from project-local paths in order:
1. `ui-rethink/principles.md`
2. `ui-audit/principles.md`
3. `prompts/principles.md`

If no file is found anywhere, proceed without principles — suggestions will reference general design reasoning instead.

Keep the principles in memory — every suggestion in Step 5 must reference at least one principle by name.

---

# STEP 2 — LOAD SCREENS INVENTORY

Check for a screens file in the project. Try in order:
1. `ui-rethink/screens.md`
2. `ui-audit/screens.md`

If found, read it and parse the table — extract the screen name (column 2) and "How to Reach" instructions (column 3) for each row.

If not found, proceed without it — the user will name the screen freehand.

---

# STEP 2B — SCAN PREVIOUS RUNS

Glob `ui-rethink/run-*/` for `*-after.png` files. Extract the screen name from each filename (strip the `-after.png` suffix and the `run-N/` prefix). Build a map of `screen name → [run numbers where an after screenshot exists]`.

This map is used in Step 3A to annotate the screen list.

---

# STEP 3A — DETERMINE TARGET SCREEN

If `--screen` is set and it matches a name in the screens inventory, use it directly.

If `--screen` is set but doesn't match any inventory entry, warn the user and ask them to confirm or pick from the list.

If `--screen` is not set and a screens inventory was loaded, present the list with run annotations from Step 2B. Screens that have after screenshots in previous runs get a `✓ run-N` tag (or `✓ run-N, run-M` if multiple); untouched screens get no tag. Example:

> "Which screen should I focus on?
> 1. dashboard-empty — Load app (default state)
> 2. dashboard-populated — Complete onboarding flow
> 3. settings-modal — Click gear icon  ✓ run-5
> ..."

Wait for the user to pick a number or type a name.

If no inventory was loaded, ask:
> "Which screen should I focus on? Describe the screen name and how to reach it."

Wait for the user's answer before continuing.

---

# STEP 3B — DETERMINE RUN FOLDER

If `--run <n>` is set, use `ui-rethink/run-<n>/` as the output folder.

If not set, check `ui-rethink/` for existing `run-*` folders and use the next number (e.g. if `run-1` exists, use `run-2`). If none exist, use `run-1`.

Create the folder if it doesn't exist.

---

# STEP 4 — NAVIGATE AND CAPTURE BEFORE SCREENSHOT

1. Use `browser_navigate` to load the base URL
2. If the target screen requires interaction to reach (e.g. clicking a nav tab, filling a form, triggering a pipeline), perform those interactions using Playwright MCP tools to get to the named state
3. Wait for the screen to settle — read the snapshot and check for loading states
4. Take a screenshot: save to `ui-rethink/run-<n>/<screen>-before.png`
5. Read the screenshot using the `Read` tool

---

# STEP 5 — SURFACE ALL RELEVANT IMPROVEMENTS

Analyze the before screenshot. Surface every relevant improvement you can identify — do not artificially cap the list. Include anything that is visible, achievable in the frontend, and grounded in a named principle. Minor polish items are fine to include as long as they earn their place.

For each suggestion:
- Give it a short label (e.g. "S1 — Tighten card spacing")
- State which principle it addresses (by name, from the loaded principles file)
- Describe the current state in one sentence
- Describe the proposed change in one sentence
- Estimate effort: Quick (CSS-only, < 10 min) or Medium (JS/HTML change, 10–30 min)

**Selection criteria:** Include changes that are:
- Visible at a glance (not subtle)
- Achievable in the frontend only (no backend changes)
- Aligned with a named principle

Present the suggestions as a numbered list and ask:
> "Which of these would you like to implement? (enter a number, or 'skip' to move on)"

Wait for the user's choice before continuing.

---

# STEP 6 — IMPLEMENT

Once the user picks a suggestion, implement it.

Rules:
- Edit only `frontend/` files (HTML, JS, CSS) — no backend changes
- Make the minimal change that achieves the suggestion — do not refactor surrounding code
- Do not add comments explaining what you changed
- Do not introduce new abstractions or helper functions unless strictly necessary
- After editing, run a syntax check if applicable (e.g. `node --check` for JS files)

---

# STEP 7 — CAPTURE AFTER SCREENSHOT AND EVALUATE

1. Navigate back to the target screen (repeat the same interaction steps from Step 4)
2. Wait for the screen to settle
3. Take a screenshot: save to `ui-rethink/run-<n>/<screen>-after.png`
4. Read both the before and after screenshots using the `Read` tool

Evaluate the change:
- **Better** — the change achieves its stated goal; the screen looks more polished, clearer, or more consistent
- **Neutral** — the change had no visible effect (implementation may not have taken effect)
- **Worse** — the change introduced a regression (describe what broke)

State the evaluation result explicitly. If **Neutral** or **Worse**, diagnose why:
- Check whether the CSS selector matches actual DOM elements (use `browser_snapshot` to inspect)
- Check whether the JS change is reachable in the current state
- Check browser console for errors

If the change is **Worse**, revert it immediately (restore the original file content) and report what happened.

---

# STEP 8 — UPDATE SCREENS INVENTORY

After the change is evaluated (regardless of outcome), check whether the implementation introduced, removed, or renamed any screens:

- **New screen added** (e.g. a new modal, a new nav tab, a new view): add a row to `screens.md` with its name and how to reach it
- **Screen removed** (e.g. a view was deleted or merged): remove its row from `screens.md`
- **Screen renamed** (e.g. "Create Report" renamed to "New Report"): update the name in `screens.md`
- **No change to screens**: skip this step entirely — do not touch `screens.md`

---

# STEP 9 — SUMMARY

Print a brief summary:

```
## UI Improve — Run <n> · <screen>

Before: ui-rethink/run-<n>/<screen>-before.png
After:  ui-rethink/run-<n>/<screen>-after.png

Change applied: <suggestion label and one-line description>
Principle: <principle name>
Evaluation: ✅ Better / ⚠️ Neutral / ❌ Worse

Files changed:
  - <file path> (~line N)
```

If evaluation is **Neutral** or **Worse**, add:
```
Diagnosis: <one sentence on why the change didn't land>
```
