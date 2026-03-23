# UI Testing Skill — Flow Design

## Overview

Runs automated visual tests against a running web application using Playwright MCP. Takes a flow document as input, executes each step in the browser, saves screenshots at assertion points, and produces a checklist report of pass/fail per step.

This skill complements `app-testing`, which handles unit and integration tests. UI testing covers what those cannot: visual state, navigation, form behaviour, and rendered output.

---

## Prerequisites

- A running local server (e.g. `localhost:3000`) or a reachable URL
- A flow document describing the steps and expected outcomes for the flow being tested (see Input Format below)
- Playwright MCP must be active in the Claude session
- All required environment variables set (e.g. API keys) — the server must be started with these in scope, not just the homepage serving

---

## Flags

| Flag | Behaviour |
|---|---|
| `--automatic` | Skip all confirmation prompts. Parse the flow (file or inline) and go straight to execution. Also skips the server-running confirmation. |

Use `--automatic` when re-running a known-good flow or scripting a batch of tests without interruption.

---

## Input — Human in the Loop

The skill starts with a clarification step (skipped if `--automatic` is set). Claude asks the user:

> "Please provide the flow to test. You can either:
> 1. Tag a flow document file (e.g. drag in `flows/login-flow.md`)
> 2. Describe the flow in plain text right here in chat"

Both are accepted. The user decides in the moment — no upfront convention required.

### Option A: File Input

The user tags or pastes a path to a flow document already stored in the project. Claude reads it using the `Read` tool.

Example invocation:
```
/ui-test
> Tag a file or describe the flow.
[user drags in flows/login-flow.md]
```

This is the preferred path for flows that will be re-run — the file stays version-controlled and reusable.

### Option B: Inline Description

The user types the flow directly in chat. Claude parses it, confirms its understanding back to the user before running, and optionally offers to save it as a flow document for future use.

Example:
```
/ui-test
> Tag a file or describe the flow.
"Go to localhost:3000/login, fill in test@example.com and password123,
click Sign In, and check that the dashboard loads with the username visible."
```

If `--automatic` is NOT set, Claude will restate the steps and ask: **"Does this look right before I run it?"**

If `--automatic` IS set, Claude parses the flow and proceeds immediately without restating or confirming.

### Flow Document Format (for file input or auto-save)

```markdown
## Flow: <flow name>
Base URL: http://localhost:3000

Steps:
1. <action description> — expect: <what should be visible or true>
2. <action description> — expect: <what should be visible or true>
...
```

**Example:**
```markdown
## Flow: User Login
Base URL: http://localhost:3000

Steps:
1. Navigate to /login — expect: login form with email and password fields visible
2. Fill email field with test@example.com — expect: field populated
3. Fill password field with password123 — expect: field populated
4. Click "Sign In" button — expect: redirect to /dashboard
5. Check page header — expect: username "Test User" visible in top navigation
```

---

## Fix 5 — Preflight Before Any Flow Steps

Whether or not `--automatic` is set, always run this before step 1:

1. Navigate to the base URL and confirm the page loaded
2. If the flow involves backend endpoints, make a smoke API call (e.g. fetch a lightweight validation endpoint) and confirm it returns non-405, non-500
3. Call `browser_console_messages` — if any `[ERROR]` entries exist at this point (missing API keys, import failures), **stop and report** before executing any steps: `"Preflight failed — console errors before flow started: [list]. Fix the server environment and retry."`

Only proceed once the preflight is clean.

---

## Execution Model

**Before step 1 — two pre-execution checks from the snapshot:**

**Fix 8 — Dropdown value validation:** For every step that specifies a dropdown value, read the actual `<option>` elements from the snapshot and confirm the value exists exactly. If not, flag it as a flow document error before executing:
> "⚠ Flow document error at Step N: '[expected]' not in dropdown options: [actual]. Using nearest match '[match]' — update the flow document."
Log this as a note on that step in the report.

**Fix — Readonly field detection:** Scan for fields the snapshot marks as `readonly` or `disabled`. Note these and skip filling them. If a field is auto-computed (e.g. age from DOB), fill the source field and let the dependent field update automatically.

---

For each step, the skill:

1. **Executes the action** using Playwright MCP tools (navigate, click, fill, etc.)
2. **Reads the snapshot** (accessibility tree — text-based, cheap) to confirm the action landed
3. **Fix 6 — Check console errors:** After any step triggering an async operation (form submit, API call, page load), call `browser_console_messages` and scan for `[ERROR]` entries. Any console error automatically marks the step **FAIL** and triggers a screenshot — even if the snapshot looks normal.
4. **Decides** whether this step warrants a screenshot (see Screenshot Decision below)
5. **Fix 7 — Async waits:** Never use `browser_wait_for(time=N)` as the primary wait for async operations. Always use `browser_wait_for(text="<completion text>")` with a generous timeout (60s minimum for pipeline/AI operations). Add a fallback for known error text. Use `time=N` only as a last resort when no deterministic completion signal exists.
6. **Asserts** against the expected outcome — using snapshot text where possible, screenshot only when visual confirmation is needed

### Screenshot Decision — Agent Judgement

Claude decides when to take a screenshot. The rule: **screenshot after substantial UI changes only** — not after every action.

**Take a screenshot after:**
- Page navigation or URL change
- Form submission
- Modal or dialog appearing / closing
- Significant content change (dashboard loading, results appearing, error state)
- Any step where the expected outcome is primarily visual (layout, styling, image)

**Do not take a screenshot after:**
- Filling a text field
- Selecting a dropdown option
- Hovering
- Minor clicks that don't change the visible page state

Claude determines this by reading the snapshot after the action. If the snapshot shows a structural change in the page (new elements, removed elements, URL change), a screenshot is taken. If the snapshot only confirms a field value or selection, no screenshot is needed.

### Screenshot Naming Convention

```
{step_number}_{action}_{expected_state}.png
```

Examples:
```
01_navigate_login_form_visible.png
04_submit_signin_redirect_dashboard.png
```

Screenshots are saved to `ui-test-results/<flow-name>/` relative to the project root. Claude reads them on demand using the `Read` tool — they are never fed inline into context unless needed.

---

## Token Strategy

| Operation | Method | Token Cost |
|---|---|---|
| Navigate, click, fill, type | Playwright MCP snapshot | ~200–400 tokens |
| Assert visual state | Playwright MCP snapshot (text) | ~200–400 tokens |
| Assert visual state (ambiguous) | Read saved screenshot file | ~1500 tokens (one-off) |
| Assert visual state (clear failure) | Skip screenshot read, log as FAIL | 0 tokens |

Screenshots are taken only when the agent judges a substantial UI change has occurred, and only *read* when the snapshot is ambiguous or the assertion is visual-only. This keeps context lean across long flows.

---

## Output: Step Report

After all steps, the skill produces a report printed to the terminal:

```
## UI Test Report — User Login Flow
Run date: 2026-03-06

Step 1: Navigate to /login
  Method: snapshot
  Expected: login form with email and password fields visible
  Result: ✅ PASS

Step 2: Fill email field
  Method: snapshot
  Expected: field populated
  Result: ✅ PASS

Step 3: Fill password field
  Method: snapshot
  Expected: field populated
  Result: ✅ PASS

Step 4: Click "Sign In" button
  Method: screenshot → 04_click_signin_redirect_dashboard.png
  Expected: redirect to /dashboard
  Result: ❌ FAIL — still on /login, error banner: "Invalid credentials"

Step 5: Check page header
  Method: skipped (blocked by Step 4 failure)
  Result: ⏭ SKIPPED

---
Summary: 3 passed, 1 failed, 1 skipped
Failed steps: 4
Screenshots saved to: ui-test-results/user-login/
```

### Step Result States

| State | Symbol | Meaning |
|---|---|---|
| Pass | ✅ | Expected state confirmed |
| Fail | ❌ | Expected state not found — describe what was found instead |
| Skipped | ⏭ | Blocked by a prior failure in the same flow |
| Unclear | ⚠️ | Screenshot ambiguous — human review needed |

---

## Failure Behaviour

- On step failure: log the failure with what was actually observed, save the screenshot, and **skip remaining dependent steps** in the flow
- Do not abort the entire test — continue with independent steps if any remain
- Do not attempt to fix failures — log and report only

---

## Directory Structure

All output is written to a `ui-testing/` folder in the project root. Claude creates this folder if it doesn't exist.

```
ui-testing/
  flows/
    login-flow.md                          ← flow documents live here
    dashboard-flow.md
    onboarding-flow.md
  <flow-name>/
    01_navigate_login_form_visible.png
    04_submit_signin_redirect_dashboard.png
    report.md                              ← written after each run
```

Flow documents saved from inline input (Option B) are also written to `ui-testing/flows/` so they are available for future runs.

---

## Decisions (Open for Review)

| Decision | Current Proposal | Alternatives |
|---|---|---|
| Input format | Either: tagged file OR inline description — user chooses in chat | File only / inline only |
| Server preflight | Always run — navigate + smoke API call + console check before step 1 | Skip with --automatic |
| Dropdown validation | Check actual options before executing — flag mismatches as flow doc errors | Silent nearest-match |
| Readonly field handling | Detect from snapshot — skip fill, note in report | Attempt fill and log error |
| Console error handling | Any [ERROR] entry = automatic FAIL + screenshot | Warn only |
| Async wait strategy | browser_wait_for(text=) with timeout — never blind time= sleep | Fixed sleep |
| Screenshot trigger | Agent decides — after substantial UI changes only (navigation, submission, modal, content change) | Every step / only on failure |
| Screenshot read trigger | On ambiguity or visual-only assertions | Always / Never |
| Blocking on failure | Skip dependent steps, continue others | Abort entire flow |
| Report format | Printed to terminal + written to report.md | Terminal only |
| Screenshot storage | `ui-testing/<flow-name>/` in project root — created automatically | Flat folder / temp dir |

---

## Relationship to Other Skills

| Skill | Scope |
|---|---|
| `testability-audit` | Identifies what flows exist and labels testability |
| `app-testing` | Unit tests, integration tests, manual checklists |
| `ui-testing` *(this skill)* | Visual/browser tests for rendered UI flows |
