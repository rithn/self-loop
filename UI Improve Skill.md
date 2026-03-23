# UI Improve Skill — Design Doc

## Overview

Performs a visual design quality audit of a running web application. Takes screenshots (reusing existing ones from `ui-testing/` when available), reads each one with Claude's vision capability, and produces a structured issue report grouped by severity.

This skill does **not** fix anything. It diagnoses. The developer acts on the report.

It complements `ui-testing`, which verifies functional flows. This skill catches what functional tests miss: font inconsistencies, layout breaks, unclickable buttons, missing content, and visual design drift across pages.

---

## Prerequisites

- A running local server or reachable URL (only needed if taking fresh screenshots)
- Playwright MCP active (only needed if taking fresh screenshots)
- Optionally: `ui-testing/` folder with existing screenshots from a prior test run
- Optionally: `prompts/flows.md` and `prompts/critical_paths.md` from the testability audit skill

---

## Flags

| Flag | Behaviour |
|---|---|
| `--page <name>` | Audit only the named page (e.g. `--page dashboard`) |
| `--component <name>` | Audit only a specific component wherever it appears (e.g. `--component modal`) |
| `--fresh` | Force new screenshots even if `ui-testing/` has existing ones |
| `--verify` | Re-audit mode — reads the most recent previous `report.md` and opens with a verification status table showing which prior issues are fixed, still present, or regressed before listing new issues |

No flag = full app audit across all available pages.

---

## Input — How Pages Are Discovered

The skill checks in order:

1. **`--page` or `--component` flag** — targeted mode, only capture/analyze that page or component
2. **`ui-testing/` folder** — if screenshots exist and `--fresh` is not set, offer to reuse them
3. **`prompts/flows.md`** — extract unique pages/views from the user flows (F-01, F-02...)
4. **`prompts/critical_paths.md`** — extract route entry points not already covered by flows
5. **Fallback** — ask the user for a base URL and list of pages to audit

When reusing existing screenshots, the user is asked to confirm before skipping the capture step.

---

## Execution Model

### Phase A — Capture (if needed)

For each page in scope:
1. Navigate using `browser_navigate`
2. Wait for the page to settle — check the snapshot for loading spinners or skeleton states; if present, wait briefly and re-check
3. Take a full-page screenshot using `browser_take_screenshot`
4. Save to `ui-audit/<timestamp>/screenshots/<page-name>.png`
5. Also capture at mobile viewport (375px wide) if the app is responsive; save as `<page-name>-mobile.png`, then resize back

**SPA multi-state capture:** For single-page applications, the initial load typically shows only one of several meaningful UI states. After the initial screenshot, inspect the snapshot for interactive triggers (buttons, forms, dropdowns). Identify each named state reachable by interaction (e.g. `home-running`, `home-completed`, `home-error`) and capture each one as a separate screenshot. Common states to look for:
- Empty / initial load state
- Loading / in-progress state (immediately after triggering an action)
- Populated / completed state (after async data loads)
- Error state (if triggerable without live credentials)

Name each screenshot descriptively (e.g. `home-completed.png`, `home-running.png`) so the report can reference a specific state per issue.

### Phase B — Per-Page Analysis

For each screenshot, read it with the `Read` tool and systematically check 6 categories.

**Notes column requirement:** For every issue logged, the Notes column must include:
- The CSS class name, DOM element id, or component name involved
- The file and approximate line number if identifiable from the source
- The root cause category: e.g. `class name mismatch`, `missing CSS rule`, `inline style overrides CSS`, `wrong display mode`, `no mobile override`, `data not loading`

**Regression check (re-audits only):** If this is running after fixes were applied (i.e. `--verify` mode or a known prior report exists), explicitly check in each state and viewport whether any previously fixed issue has regressed or whether a fix introduced a new problem in a different context (e.g. a font-size increase that works on desktop but wraps on mobile).

#### 1. Typography
- Inconsistent font sizes across same-level headings (e.g. two H1s that look different sizes)
- Inconsistent font weights on similar elements (bold vs regular for same type of label)
- Text overflowing or truncated by a fixed-height container
- Text running outside its bounding box or overlapping adjacent elements
- Line height causing lines to overlap

#### 2. Color & Visual Contrast
- Same-type buttons or links with different colors across the page
- Text that appears low-contrast against its background (obvious cases, not computed)
- Inconsistent border, shadow, or highlight treatment on similar components (e.g. some cards have shadows, some don't)

#### 3. Layout & Spacing
- Misaligned elements within a row, grid, or form
- Inconsistent padding or margin between similar components
- Elements overflowing their container (visible horizontal scroll bar, content cut off)
- Elements too close to the viewport edge with no margin/padding
- Overlapping elements (z-index issues)

#### 4. Interactive Elements
- Buttons or tap targets that appear too small (visually under ~44px)
- Clickable things that don't look interactive (no visual affordance — no border, color, or cursor cue)
- Non-clickable things that look like buttons or links
- Disabled-looking elements that should be active
- No visible focus or hover state on primary actions

#### 5. Content Completeness
- Placeholder text visible (`Lorem ipsum`, `[placeholder]`, `...`)
- `null`, `undefined`, `NaN`, or empty brackets in rendered text
- Broken or missing images (empty image boxes, alt text showing instead of image)
- Empty sections that clearly have reserved space but no content
- Truncated labels where full text is necessary (e.g. a button that reads "Subm")

#### 6. Proportions & Fit
- Images stretched or squished (wrong aspect ratio)
- Text wrapping unexpectedly, causing layout to break (e.g. a nav item wrapping to two lines)
- Modals, dropdowns, or tooltips clipped by a parent container's overflow
- Charts or graphs clipped or not filling their container

### Phase C — Cross-Page Consistency

After all individual screenshots are analyzed, do a comparison pass across pages:

- **Buttons** — do primary, secondary, and destructive buttons look the same across pages?
- **Headings** — is the heading hierarchy (H1 size, H2 size, etc.) consistent?
- **Cards / panels** — are similar content containers styled consistently?
- **Forms** — do input fields, labels, and error states look the same?
- **Navigation** — does the nav/header look identical on all pages?
- **Spacing rhythm** — does the vertical spacing between sections feel consistent?

This phase catches design drift that individual-page analysis misses.

---

## Output: Report

Written to `ui-audit/<timestamp>/report.md` and printed to terminal.

```
## UI Audit Report — <Project Name>
Date: <today>
Mode: Full audit | Targeted — <page or component> | Re-audit (--verify)
Pages audited: N
Screenshots: ui-audit/<timestamp>/screenshots/

---

### Previously reported issues — verification status
(Include this section only when running with --verify or when a prior report.md exists)

| Issue | Status |
|---|---|
| H1 — Mobile layout broken | ✅ Fixed |
| M1 — Card class mismatch | ✅ Fixed |
| M3 — Confidence banner unstyled | ⚠️ Regressed — fix introduced mobile wrap |
| H2 — Raw Markdown in excerpts | ✅ Fixed |

---

### 🔴 High — Broken or Unusable (N issues)

| Page | Element / Location | Issue | Notes |
|---|---|---|---|
| /dashboard | Revenue card | Number displays "NaN" — data not loading | `data.revenue` is undefined; `renderDashboard()` in `app.js:82` does not guard for null |
| /settings | Save button | Text "Save Chang" truncated — button too narrow | `.save-btn` has `width: 80px` hard-coded in `settings.css:44`; text needs ~100px |

### 🟡 Medium — Inconsistent or Visually Wrong (N issues)

| Page | Element / Location | Issue | Notes |
|---|---|---|---|
| /profile | Primary CTA | Blue (#2563eb) — differs from green used on /dashboard | Class mismatch: `btn-primary` on /profile vs `btn-action` on /dashboard; different CSS rules |
| /reports | Section heading | Font size appears smaller than equivalent H2 on other pages | `.report-heading` overrides global `h2` with `font-size: 0.85rem` in `reports.css:12` |

### 🟢 Low — Nitpicks (N issues)

| Page | Element / Location | Issue | Notes |
|---|---|---|---|
| /login | Footer | Slightly more bottom padding than other pages | `footer` has `padding-bottom: 24px` on /login vs `16px` elsewhere — no global footer rule |

---

Summary: N high, N medium, N low issues across N pages.
Screenshots saved to: ui-audit/<timestamp>/screenshots/

---

## Suggested Fixes

### H1 — <Issue title>

**File:** `path/to/file.ext` — relevant function or CSS rule

Brief explanation of the root cause and the minimal change needed.

```
// before
bad code

// after
fixed code
```

### M1 — <Issue title>

...
```

**Suggested Fixes section rules:**
- Include for every High and Medium issue
- Skip Low issues unless the fix is a single token change
- Always include file path and approximate line
- Keep each fix to the minimal change — do not refactor surrounding code
- Label them clearly as suggestions; no code is actually changed by this skill

---

## Directory Structure

```
ui-audit/
  <timestamp>/
    screenshots/
      dashboard.png
      dashboard-mobile.png
      settings.png
    report.md
```

If reusing screenshots from `ui-testing/`, the report is still written to `ui-audit/<timestamp>/` — the `ui-testing/` folder is not modified.

---

## Decisions

| Decision | Current Approach | Alternatives |
|---|---|---|
| Auto-fix | No — report + suggested fixes only | Apply fixes automatically |
| Scope | Full app by default; `--page` / `--component` for targeted | Always targeted |
| Screenshot reuse | Offer to reuse from `ui-testing/` if available | Always take fresh |
| Mobile capture | Always capture at 375px if app is responsive | Opt-in flag |
| Contrast checking | Visual judgment only (obvious cases) | Could compute with DOM inspection |
| Page discovery | flows.md → critical_paths.md → ask user | Always ask |
| SPA states | Capture all named states reachable by interaction | Initial load only |
| Re-audit mode | `--verify` reads prior report and opens with verification table | Always treat as fresh |
| Notes depth | Root cause + file/line required for every issue | Surface description only |
| Regression check | Explicitly check for regressions in re-audit runs | Passive (catch if visible) |

---

## Relationship to Other Skills

| Skill | Scope |
|---|---|
| `testability-audit` | Identifies flows, produces `flows.md` and `critical_paths.md` |
| `ui-testing` | Functional flow tests — verifies interactions work |
| `ui-improve` *(this skill)* | Visual quality audit — catches design bugs and inconsistencies |
