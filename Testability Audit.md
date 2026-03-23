# Testability Audit

A pre-loop audit that checks whether the tickets and app spec are actually verifiable before handing them to the build-verify loop. Think of it as a **verifier of the planner** — catching untestable tickets early rather than letting them trip up the builder/verifier loop at runtime.

---

## When to Run

After `/code-create-spec` produces `app_spec.txt` and `tickets.md`, and **before** running `/code-build-loop` or `/code-app-testing`. The audit is a blocking gate — if tickets fail it, fix them before starting either loop.

---

## Phase 1: Flow Extraction

### 1a. Spec-derived flows

Read the provided spec, docs, or description and extract all distinct user flows. Examples:
- Sign up / onboarding
- Login / logout
- Password reset
- Core feature flows (e.g. creating a project, placing an order)
- Settings / profile management
- Error / edge case flows (e.g. failed payment, expired session)

For each flow, record:
- Flow name
- Brief description (start to finish from the user's perspective)

### 1b. Source code discovery

Scan the codebase for active entry points not covered by the spec-derived flows:
- Route definitions (Flask, FastAPI, Django URLs, Express routes, etc.)
- CLI command handlers
- Event handlers and message consumers
- Scheduled jobs / cron tasks

Match discovered entry points against spec-derived flows. Any entry point not mapped to an existing flow is flagged as an **undocumented flow** and added to the list with an `[auto-discovered]` tag.

---

## Phase 2: User Confirmation of Flow Coverage

Present the merged flow list (spec-derived + auto-discovered) to the user.

Ask:
- Are all relevant flows covered?
- Should any auto-discovered flows be excluded?
- Are there flows missing that neither the spec nor the code revealed?

**Loop:** Incorporate feedback and re-present until the user explicitly confirms coverage is complete.

Output: `flows.md` — confirmed list of all user flows.

---

## Phase 3: Critical Path Mapping

For each confirmed flow, read the actual source files and trace the real call chain — do not infer or guess from the spec.

For each function in the call chain, record:
```
Function: create_project
Source: services/project_service.py:42
Called by: routes/projects.py:18
Label: unit
```

Required fields per function:
- `Function` — the function/method name
- `Source` — file path and line number where it is defined
- `Called by` — file path and line number of the call site
- `Label` — testability classification (see below)

If a function cannot be located in source, mark it `[unverified]`. Unverified functions block test generation for that flow until resolved.

Testability labels:
- `unit` — can be called directly in a test with no external dependencies
- `integration` — requires a running server, database, or other service
- `cli` — reachable via a CLI command or curl
- `untestable` — requires browser interaction, hardware, human input, or an unbypassable live third-party service

Output: `critical_paths.md` — one section per flow, functions in call order with full evidence and testability labels.

---

## What the Audit Checks

### 1. External Dependencies

The biggest hidden blocker for CLI testability is anything that requires a human, a browser session, or a live third-party service to proceed. Flag these at the project level before looking at individual tickets:

- **OAuth / SSO login flows** — if the app requires a browser-based OAuth flow to get an auth token, API-level testing is blocked unless the spec includes a test-mode bypass (e.g. a static dev token, a mock auth endpoint, or a CLI login command)
- **Third-party API keys** — any integration (Stripe, SendGrid, Twilio, etc.) that requires a live key. Flag which tickets depend on these and whether a sandbox/mock is available
- **External webhooks** — flows triggered by an inbound webhook from a third party can't be exercised via curl unless the spec includes a way to fire a synthetic webhook locally
- **File system or device dependencies** — flows that require a specific local file, camera, microphone, or hardware peripheral
- **Email / SMS verification** — signup or auth flows that send a code to an external address and wait for the user to paste it back

For each external dependency found, confirm: **is there a test-mode path that avoids it?** If not, that flow is untestable in the loop and must be noted.

### 2. Verification Block Quality

For every ticket, check the verification block:

| Problem | Example | Fix |
|---|---|---|
| No verification block | Ticket ends after Scope | Add a concrete bash/test command |
| Vague assertion | `# Expected: output looks correct` | Replace with exact expected value or exit code |
| Browser-only check | `open http://localhost:3000 and click...` | Replace with curl, pytest, or CLI equivalent |
| Depends on human judgement | `confirm the UI renders nicely` | Assert on HTTP 200 + HTML content, or move outside the loop |
| Non-deterministic expected output | timestamp, UUID, random value in assertion | Assert on structure/shape, not the value itself |
| Verification assumes prior state | assumes data from a previous test exists | Make the ticket self-contained — set up its own state |

### 3. CLI Reachability

For every feature in the spec, confirm there is a CLI-reachable entry point:

- REST endpoint reachable via `curl`
- Function callable via `python -c` or a test script
- CLI command that triggers the behaviour
- MCP tool that exercises the feature

Flag anything where the only entry point is a browser interaction.

### 4. Environment Assumptions

Check that verification commands don't silently assume:
- A specific machine path not in the repo
- A service already running that the ticket doesn't start
- An API key that isn't documented in the spec
- A database pre-seeded with data not created by the ticket itself

### 5. Dependency Validity

- Every `Depends On` reference points to a real ticket ID
- No circular dependencies
- The first ticket has `Depends On: None`
- Tickets don't skip dependencies (e.g. writing to a DB before the DB setup ticket)

---

## Audit Output

The audit produces the following files and a report.

### flows.md
Confirmed list of all user flows (spec-derived + auto-discovered, after user sign-off). One entry per flow with name and description.

### critical_paths.md
One section per flow listing functions in call order, each with a testability label: `unit`, `integration`, `cli`, or `untestable`.

### Audit Report

Four sections:

#### Environment Setup Checklist
A complete list of everything the user must provide before starting the loop. The loop should not be started until every item here is confirmed. Format as a `.env` template the user can fill in:

```
## Required before starting the build-verify loop
## Copy to .env in the project root and fill in all values

# Third-party API keys
STRIPE_SECRET_KEY=           # Stripe sandbox key — needed by TICKET-014, TICKET-021
SENDGRID_API_KEY=            # SendGrid — needed by TICKET-018 (email verification)

# Auth / session
DEV_AUTH_TOKEN=              # Static token for test-mode login bypass — see TICKET-003

# External service URLs (if self-hosted or sandboxed)
WEBHOOK_RELAY_URL=           # e.g. smee.io URL for local webhook testing — TICKET-022
```

Also note any non-env dependencies:
- Files that must exist locally before certain tickets run
- Services that must be started manually (e.g. a local SMTP server)
- Accounts or sandbox registrations the user needs to create

### Blocked
Tickets or project-level issues that **must be fixed** before the loop can run. The verifier will either crash, produce a false positive, or silently pass on broken code.

```
PROJECT: OAuth login requires browser — no test-mode token bypass in spec
TICKET-007: Verification block asserts on a hardcoded UUID — non-deterministic
TICKET-012: Verification opens a browser URL — no CLI equivalent
TICKET-019: Depends on TICKET-018 but TICKET-018 doesn't exist
```

### Warnings
Issues that may cause problems but aren't guaranteed blockers.

```
TICKET-004: Verification assumes server is already running — no startup command in the block
PROJECT: Stripe integration requires live API key — confirm sandbox key is sufficient
```

### Passed
Ticket count that passed all checks. If this equals the total ticket count, there are no project-level blockers, and all environment variables are provided, the loop is clear to start.

---

## Fix Patterns

**Vague assertion → exact assertion**
```bash
# Before
curl http://localhost:8000/api/health
# Expected: returns something

# After
curl -s http://localhost:8000/api/health | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['status']=='ok', d"
# Expected: exits 0
```

**Browser-only → curl**
```bash
# Before
# Open http://localhost:3000/dashboard and verify cards load

# After
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/dashboard/summary
# Expected: 200
```

**State dependency → self-contained**
```bash
# Before (assumes a user already exists)
curl -X POST http://localhost:8000/api/login -d '{"email":"test@test.com"}'

# After (creates the user first)
curl -s -X POST http://localhost:8000/api/users -d '{"email":"test@test.com","password":"pass123"}'
curl -s -X POST http://localhost:8000/api/login -d '{"email":"test@test.com","password":"pass123"}' | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'token' in d"
# Expected: exits 0
```

**OAuth blocker → test-mode bypass**
```
# In app_spec.txt, add:
# - A /api/auth/dev-token endpoint (disabled in production) that returns a valid session token
#   for a seeded test user, requiring no OAuth flow
# Then all tickets that need auth can call this endpoint first
```

---

See also: [[Spec Creation]], [[Coding loops]]
