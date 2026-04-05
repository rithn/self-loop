# Testability Audit (`/code-testability-audit`)

> Type `/code-testability-audit` to gate-check your tickets and spec before starting the build loop. Finds untestable tickets, missing env vars, and broken dependencies — and fixes them.

---

## When to run

After `/code-create-spec` produces `app_spec.txt` and `tickets.md`, and **before** running `/code-build-loop` or `/code-app-testing`. The audit is a blocking gate — the build loop should not start until it clears.

---

## Pre-build vs. post-build mode

The skill detects which mode it is in based on whether code already exists:

- **Pre-build mode** — generates `critical_paths.md` stubs from the spec, with all functions marked `[unverified]`. These block test generation until the build fills them in.
- **Post-build mode** — traces `critical_paths.md` from actual source files with real line numbers. Reports which mode it is in.

---

## What it checks

### Check 1: External dependencies (project-level)

Flags anything requiring a human, a browser session, or a live third-party service:
- OAuth / SSO login flows with no test-mode bypass
- Third-party API keys (Stripe, SendGrid, Twilio, etc.) — notes which tickets depend on each
- Inbound webhooks from external services with no local simulation path
- File system or device dependencies
- Email / SMS verification loops
- System binaries called via subprocess (libreoffice, ffmpeg, etc.)

**BLOCKED** = no bypass exists. **WARNING** = bypass available but not documented.

### Check 2: Verification block quality

For every ticket:
- Missing verification block → **BLOCKED**
- Vague assertion (`looks correct`, `returns something`) → **BLOCKED**
- `grep ... | head -N` with prose expected output → **BLOCKED** (replace with `grep -q` + explicit exit code)
- Browser-only check → **BLOCKED**
- Non-deterministic expected output (raw UUID, timestamp, random value) → **BLOCKED**
- Assumes prior state not set up by this ticket → **BLOCKED**
- Server assumed running with no startup command → **WARNING**
- Relative path that won't resolve from the builder's working directory → **WARNING**
- Excel/CSV/DB column accessed by a string name that doesn't match the actual header → **WARNING**
- External binary used without a `command -v` pre-flight in the verification block → **WARNING**

### Check 3: CLI reachability

For every feature in the spec: is there a CLI-reachable entry point (curl, pytest, python -c, CLI command, MCP tool)? Browser-only entry points → **BLOCKED**.

### Check 4: Environment assumptions

Verification commands must not silently assume:
- A machine path not in the repo → **BLOCKED**
- A running service the ticket doesn't start → **WARNING**
- An undocumented API key → **BLOCKED**
- A pre-seeded database not created by the ticket → **BLOCKED**
- A system binary not documented in environment setup → **WARNING**

### Check 5: Dependency validity

- `Depends On` references a non-existent ticket ID → **BLOCKED**
- Circular dependency → **BLOCKED**
- First ticket has a dependency → **WARNING**
- Ticket skips a logical dependency → **WARNING**

---

## Audit output files

### `prompts/flows.md`

Confirmed list of all user flows: spec-derived flows plus any entry points auto-discovered from existing source code (tagged `[auto-discovered]`). Written after user confirms coverage is complete. See [example](../templates/code-testability-audit/examples/flows.md).

### `prompts/critical_paths.md`

See [example](../templates/code-testability-audit/examples/critical_paths.md).

One section per flow. For each function in the call chain:
```
Function: function_name
Source:   path/to/file.py:LINE_NUMBER
Called by: path/to/caller.py:LINE_NUMBER
Label:    unit | integration | cli | untestable
```

Testability labels:
- `unit` — callable directly with no external dependencies
- `integration` — requires running server, database, or external service
- `cli` — reachable via curl/pytest/python -c
- `untestable` — requires browser, hardware, or unbypassable live third-party

Any function that cannot be located in source is marked `[unverified]` and blocks test generation for that flow.

Closes with an **Integration Boundary Summary** table showing which external services affect which flows.

### `.env.template`

Human-readable file the user fills in, with comments linking each variable to the tickets that need it.

### `.env.required`

Machine-readable list of variable names (one per line). The build loop script reads this at startup and fails fast if any variable is unset.

### `.system-deps.required`

Machine-readable list of system binary names (one per line). The loop script runs `command -v` on each at startup.

All three files are always written — even if there are no variables or dependencies (written with a comment saying so).

---

## Audit report format

```
## Testability Audit — {Project Name}
Tickets checked: N
Mode: Pre-build | Post-build

### Environment Setup Checklist
[.env template, system dependencies, other setup required]

### Blocked (N)
[Issues that must be fixed before the loop can run]

### Warnings (N)
[Issues that may cause problems but aren't guaranteed blockers]

### Passed (N)
[N tickets passed all checks]

### Verdict (PROVISIONAL)
CLEAR TO RUN — all tickets passed, environment checklist complete.
  OR
NOT CLEAR — fix N blocked issue(s) before starting the loop.
```

---

## Fix and re-check

For each blocked ticket and warning, the skill offers a concrete fix with a before/after example and asks for confirmation before modifying `tickets.md`. After all fixes are applied, it re-runs all five checks and issues a **Final Verdict**.

---

## Flow coverage confirmation

After the audit, the skill presents the merged list of all flows (spec-derived + auto-discovered) and asks whether coverage is complete. Once confirmed, it writes `prompts/flows.md`. This file is required by `/code-app-testing` and `/code-ui-improve`.

---

## Relationship to other skills

| Skill | When to run |
|---|---|
| `/code-create-spec` | Before this — produces `app_spec.txt` and `tickets.md` |
| `/code-build-loop` | After this — the audit must clear before the loop starts |
| `/code-app-testing` | After this — uses `flows.md` and `critical_paths.md` |
