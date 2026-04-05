# UI Improve Skill (`/code-ui-improve`)

> Type `/code-ui-improve` to run a visual design quality audit against a running web app. Finds font inconsistencies, layout breaks, color drift, missing content, and unclickable elements. Produces a severity-ranked issue report with suggested fixes.

---

## What it does

Takes screenshots of a running application (reusing existing ones from `ui-testing/` if available), reads each one with Claude's vision capability, and produces a structured issue report grouped by severity. Issues are logged at three severity levels — High (broken/unusable), Medium (inconsistent/wrong), Low (nitpicks).

**This skill does not fix anything.** It diagnoses. The developer acts on the report.

---

## Prerequisites

- A running local server or reachable URL (only needed if taking fresh screenshots)
- Playwright MCP active (only needed if taking fresh screenshots)
- Optionally: `ui-testing/` folder with existing screenshots from a prior test run
- Optionally: `prompts/flows.md` and `prompts/critical_paths.md` from the testability audit

---

## Flags

| Flag | Behaviour |
|---|---|
| `--page <name>` | Audit only the named page (e.g. `--page dashboard`) |
| `--component <name>` | Audit only a specific component wherever it appears |
| `--fresh` | Force new screenshots even if `ui-testing/` has existing ones |
| `--verify` | Re-audit mode — reads the most recent prior `report.md` and opens with a verification status table showing which prior issues are fixed, still present, or regressed |

No flags = full app audit across all available pages.

---

## How pages are discovered

The skill checks in order:
1. `--page` or `--component` flag (targeted mode)
2. `ui-testing/` folder (existing screenshots, offered for reuse if `--fresh` not set)
3. `prompts/flows.md` — extracts unique pages/views from user flows
4. `prompts/critical_paths.md` — extracts route entry points not already covered
5. Fallback: asks for a base URL and list of pages

---

## Phase A — Screenshot capture (if needed)

For each page:
1. Navigate using `browser_navigate`
2. Wait for the page to settle (checks for loading spinners or skeleton states)
3. Take a full-page screenshot; save to `ui-audit/<YYYY-MM-DD>/screenshots/<page-name>.png`
4. If the app is responsive, also capture at 375px wide as `<page-name>-mobile.png`

**SPA multi-state capture:** For single-page applications, captures all meaningful UI states reachable by interaction — not just the initial load. Common states: empty/initial, loading/in-progress, populated/completed, error. Each state is named descriptively (e.g. `home-completed.png`) and treated as a separate subject in the analysis.

---

## Phase B — Per-page visual analysis

For each screenshot, reads it with the `Read` tool and checks 6 categories. Every issue logged must include in the Notes field: the CSS class, element id, or component name; the file and approximate line if identifiable; and the root cause category.

### Category 1: Typography
- Inconsistent font sizes across same-level headings
- Inconsistent font weights on similar elements
- Text overflowing or truncated by a fixed container
- Text running outside its bounding box or overlapping adjacent elements
- Line height causing lines to visually overlap

### Category 2: Color & Visual Contrast
- Different colors on what appear to be same-type buttons or links
- Text with visually low contrast against its background (obvious cases)
- Inconsistent border, shadow, or highlight treatment on similar components

### Category 3: Layout & Spacing
- Misaligned elements within a row, grid, or form
- Inconsistent padding or margin between similar components
- Content overflowing a container (horizontal scroll bar, content cut off)
- Elements touching or extremely close to the viewport edge
- Overlapping elements (z-index issues)

### Category 4: Interactive Elements
- Buttons or tap targets that appear too small (visually under ~44px)
- Clickable things with no visual affordance (no color, border, or cursor cue)
- Non-interactive elements styled to look like buttons or links
- Disabled-looking elements that should be active
- No visible hover or focus state on primary actions

### Category 5: Content Completeness
- Placeholder text visible (`Lorem ipsum`, `[placeholder]`, `...`, `Sample text`)
- `null`, `undefined`, `NaN`, or empty brackets in rendered UI text
- Broken or missing images (empty boxes, alt text showing instead of image)
- Reserved sections with no content
- Button or label text truncated mid-word

### Category 6: Proportions & Fit
- Images stretched or squished (wrong aspect ratio)
- Text wrapping unexpectedly, breaking the layout (e.g. nav item on two lines)
- Modals, dropdowns, or tooltips clipped by a parent container's overflow
- Charts or content panels not filling their allocated space

**Regression check (re-audits):** In `--verify` mode, explicitly checks whether any previously fixed issue has regressed, or whether a fix introduced a new problem in a different state or viewport.

---

## Phase C — Cross-page consistency pass

After all individual pages are analyzed, reads screenshots as a group and compares:
- Buttons — do primary, secondary, and destructive buttons look the same across pages?
- Headings — is the heading hierarchy consistent in size and weight?
- Cards / panels — are content containers styled consistently?
- Forms — do input fields, labels, and error states match?
- Navigation — does the header look identical on every page?
- Vertical spacing — does the rhythm between sections feel consistent?

Cross-page issues are tagged `[cross-page]` in the location field.

---

## Report format

Written to `ui-audit/<YYYY-MM-DD>/report.md` and printed to the terminal.

```
## UI Audit Report — <Project Name>
Date: <today>
Mode: Full audit | Targeted — <page or component> | Re-audit (--verify)
Pages audited: N
Screenshots: ui-audit/<YYYY-MM-DD>/screenshots/

---

### Previously reported issues — verification status
(Only when --verify is set)
| Issue | Status |
| H1 — Mobile layout broken | ✅ Fixed |
| M1 — Card class mismatch | ⚠️ Regressed |

---

### 🔴 High — Broken or Unusable (N issues)
| Page | Element / Location | Issue | Notes |

### 🟡 Medium — Inconsistent or Visually Wrong (N issues)
| Page | Element / Location | Issue | Notes |

### 🟢 Low — Nitpicks (N issues)
| Page | Element / Location | Issue | Notes |

---
Summary: N high, N medium, N low issues across N pages.

---
## Suggested Fixes
[Every High and Medium issue gets a fix entry with file path, line, root cause, before/after snippet]
```

**Severity definitions:**
- **High**: Broken, unusable, or missing content (user cannot proceed, text is wrong, image missing)
- **Medium**: Visually incorrect or inconsistent (wrong color, misaligned, wrong size)
- **Low**: Minor polish issues (spacing slightly off, low-traffic area)

Suggested fixes are included for every High and Medium issue. Low issues only if the fix is a single token change. No code is modified by this skill.

---

## Output structure

```
ui-audit/
  <YYYY-MM-DD>/
    screenshots/
      dashboard.png
      dashboard-mobile.png
      settings.png
    report.md
```

If reusing screenshots from `ui-testing/`, the report is still written to `ui-audit/<YYYY-MM-DD>/` — `ui-testing/` is never modified.

---

## Relationship to other skills

| Skill | Scope |
|---|---|
| `/code-testability-audit` | Identifies flows, produces `flows.md` and `critical_paths.md` |
| `/code-ui-testing` | Functional flow tests — verifies interactions work |
| `/code-ui-improve` (this skill) | Visual quality audit — design bugs and inconsistencies |
