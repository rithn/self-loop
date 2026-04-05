# UI Testing Skill (`/code-ui-testing`)

> Type `/code-ui-testing` to run visual flow tests against a running web application using Playwright MCP — step by step, with targeted screenshots and a pass/fail report.

---

## What it does

Takes a flow document or inline description, executes each step in the browser using Playwright MCP, and produces a `report.md` with pass/fail per step. Screenshots are taken only when there is a substantial UI change — not after every action.

This skill covers what unit and integration tests cannot: visual state, navigation, form behaviour, and rendered output.

---

## Prerequisites

- A running local server (e.g. `localhost:3000`) or a reachable URL
- Playwright MCP active in the Claude session
- All required environment variables set — the server must be started with these in scope

---

## Flags

| Flag | Behaviour |
|---|---|
| `--automatic` | Skip all confirmation prompts and the server-running confirmation. Parse the flow (file or inline) and jump straight to execution. |

Use `--automatic` when re-running a known-good flow or scripting a batch of tests.

---

## Step 1 — Get the flow

If `--automatic` is set and a flow file or inline description was provided, skip asking and go straight to parsing.

Otherwise:

> "Please provide the flow to test. You can either:
> 1. Tag or paste the path to a flow document (e.g. `ui-testing/flows/login-flow.md`)
> 2. Describe the flow in plain text here in chat"

**Option A — File input:** Reads the file using the `Read` tool and parses the base URL and steps list.

**Option B — Inline description:** Parses the description into structured steps. If `--automatic` is NOT set, restates the parsed steps and asks for confirmation. If confirmed, offers to save the flow as a document to `ui-testing/flows/` for future runs.

### Flow document format

```markdown
## Flow: <flow name>
Base URL: http://localhost:3000

Steps:
1. <action> — expect: <observable outcome>
2. <action> — expect: <observable outcome>
```

---

## Step 2 — Preflight server check

Always runs before any flow steps, even in `--automatic` mode:

1. Navigate to the base URL and confirm the page loaded
2. If the flow involves backend endpoints, make a smoke API call to a lightweight endpoint and confirm non-405, non-500 response
3. Check `browser_console_messages` — if any `[ERROR]` entries exist (missing API keys, import failures), stop and report before executing any steps

---

## Step 3 — Pre-execution checks (from snapshot before step 1)

**Readonly field detection:** Scans for fields the snapshot marks as `readonly` or `disabled`. These are noted in the report and not filled. If a field is auto-computed (e.g. age from DOB), the source field is filled and the dependent field is allowed to update automatically.

**Dropdown value validation:** For every step specifying a dropdown value, reads the actual `<option>` elements from the snapshot and confirms the value exists exactly. If it doesn't match, flags it as a flow document error before executing:
> "⚠ Flow document error at Step N: value '[expected]' not found in dropdown options: [actual options]. Using nearest match '[match]' — update the flow document."

---

## Step 4 — Execute the flow

For each step:

1. **Execute the action** using the appropriate Playwright MCP tool (`browser_navigate`, `browser_click`, `browser_type`, `browser_fill_form`, `browser_select_option`, `browser_press_key`)
2. **Read the snapshot** after every action to confirm it registered
3. **Check console errors** after any step triggering an async operation (form submit, API call, page load). Any `[ERROR]` entry automatically marks the step FAIL and triggers a screenshot, even if the snapshot looks normal
4. **Decide on screenshot** — take only when there is a substantial UI change (see below)
5. **Wait for async results** — never use `browser_wait_for(time=N)` as the primary wait. Always use `browser_wait_for(text="<completion text>")` with a generous timeout (60s minimum for pipeline/AI operations). Use time-based waits only as a last resort
6. **Assert** against the expected outcome

### Screenshot decision rule

**Take a screenshot after:**
- Page navigation or URL change
- Form submission result
- Modal or dialog appearing / closing
- Significant content change (new section loaded, error state, success state)
- Any step where the expected outcome is primarily visual

**Do not take a screenshot after:**
- Filling a text field
- Selecting a dropdown option
- Hovering
- Any action that doesn't change the visible page structure

### Step result states

| State | Symbol | Meaning |
|---|---|---|
| Pass | ✅ | Expected state confirmed in snapshot or screenshot |
| Fail | ❌ | Expected state not found — what was actually observed is logged |
| Skipped | ⏭ | Blocked by a prior failure in the same flow |
| Unclear | ⚠️ | Snapshot ambiguous — the skill reads the saved screenshot to make a final call |

On FAIL: saves a screenshot regardless of the screenshot decision rule, logs what was observed, and skips any steps that depend on the failed step. Independent steps continue.

---

## Step 5 — Write the report

Written to `ui-testing/<flow-name>/report.md` and printed to the terminal.

```
## UI Test Report — <Flow Name>
Run date: <date>
Base URL: <url>

Step 1: <action>
  Method: snapshot / screenshot → <filename>
  Expected: <expected outcome>
  Result: ✅ PASS / ❌ FAIL — <what was observed> / ⏭ SKIPPED / ⚠️ UNCLEAR

---
Summary: N passed, N failed, N skipped, N unclear
Failed steps: N, N
Screenshots saved to: ui-testing/<flow-name>/
```

---

## Output structure

```
ui-testing/
  flows/
    login-flow.md              ← flow documents (version-controlled, reusable)
    dashboard-flow.md
  <flow-name>/
    01_navigate_login_form_visible.png
    04_submit_signin_redirect_dashboard.png
    report.md
```

---

## Relationship to other skills

| Skill | Scope |
|---|---|
| `/code-testability-audit` | Identifies flows, produces `flows.md` and `critical_paths.md` |
| `/code-app-testing` | Unit and integration tests |
| `/code-ui-testing` (this skill) | Visual browser tests — navigation, forms, rendered output |
| `/code-ui-improve` | Design quality audit — typography, layout, color, content completeness |
