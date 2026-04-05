# App Testing Skill (`/code-app-testing`)

> Type `/code-app-testing` to generate and run a full test suite — unit tests, integration tests, and manual checklists — for all confirmed user flows.

---

## What it does

Takes the outputs of `/code-testability-audit` and produces a complete test suite. Generates all fixtures and tests first, then runs unit tests globally, then runs integration tests sequentially per flow.

Framework is auto-detected from the project:

| Signal | Framework |
|---|---|
| `*.py`, `pytest.ini`, `pyproject.toml` | pytest |
| `package.json` with jest in deps | jest |
| `go.mod` | go test |
| `Gemfile`, `*.rb` | rspec |

If multiple languages are present, a framework is selected per language. If detection is ambiguous, asks before continuing.

---

## Prerequisites

Requires these files produced by `/code-testability-audit`:
- `prompts/flows.md` — confirmed list of all user flows
- `prompts/critical_paths.md` — functions per flow with testability labels

If either is missing, the skill tells you to run `/code-testability-audit` first.

---

## Step 1 — Real calls vs. mocks

Before generating any tests, asks:

> "Should tests use **real API calls** for external services or **mocks**? Default is real calls with a skip guard if the API key is absent."

**Real calls (default):** Tests that call external services are marked with a skip guard (e.g. `@pytest.mark.live_llm`) that skips if the required env var is unset. For every function calling an external AI/LLM service, at least one **known-bad → must produce output** test is generated — an input known to trigger a non-empty result, asserting `len(result) >= 1`. This catches silent empty returns that naive happy-path tests miss.

**Mocks:** Standard mocking. Strategy documented in a comment in `tests/fixtures.<ext>`.

---

## Step 2 — Generate data fixtures

Scans `critical_paths.md` for all data entities referenced across flows and generates `tests/fixtures.<ext>` containing:
- One factory function per entity with sensible defaults
- Parameters for field-level overrides
- Each factory handles its own teardown

Two preflight fixtures are also added to `conftest.py`:

**Env var guard (all tests):** Session-scoped fixture that reads `.env.required` and fails immediately with a clear list of missing variables before any test runs.

**Server preflight (integration tests only):** Session-scoped fixture that makes a real HTTP call to a known endpoint before integration tests start. Exits immediately on connection failure or unexpected status.

**Self-containment rule** enforced for every test: each test sets up all state it needs via factories — no test relies on state from another test, and no test assumes execution order.

---

## Step 3 — Generate unit tests

Only tests functions that appear directly in `critical_paths.md` — functions on the critical path of a user flow. Internal helpers not on a flow's call chain are not tested.

Tests behaviour from the caller's perspective — not internal implementation details.

For each qualifying function:
- Happy path
- Edge cases (empty input, boundary values, null/None/undefined)
- Known failure modes

Placed under `tests/unit/`, mirroring the source directory structure. One test file per source file.

---

## Step 4 — Generate integration tests

For each flow in `flows.md` where all functions are testable (no `untestable` labels):
- One test file per flow exercising the full flow end-to-end
- Self-contained via factories
- Placed under `tests/integration/test_<flow_name>.<ext>`

**Assertion rule:** Every integration test must assert on at least one of:
- Response body content
- State change in the database or store
- Side effect that occurred (mock called, file written, queue message present)

Tests whose only assertion is a status code are flagged `[shallow]` with a note on what observable state is missing.

---

## Step 5 — Generate manual checklists

For every flow containing at least one `untestable` function:
- `<flow-name>-manual.md` alongside `flows.md`
- Contains: what the flow does, pre-conditions, numbered steps, expected outcome at each step, which functions are untestable and why

---

## Step 6 — Run unit tests (all at once)

```bash
pytest tests/unit/ -v      # Python
npx jest tests/unit/       # JavaScript
go test ./tests/unit/...   # Go
```

On any failure: prints full stack trace, diagnoses and fixes, re-runs the full unit suite to confirm all pass. Does not proceed to integration tests until unit suite is fully green.

---

## Step 7 — Run integration tests (sequentially per flow)

Runs one flow at a time in the order they appear in `flows.md`. On any failure: diagnoses the root cause, fixes the source code or test, re-runs that flow's test to confirm it passes, then moves to the next flow.

Manual-only flows: prints the absolute path to the checklist file and skips.

---

## Step 8 — Summary report

```
## Test Run Summary — {Project Name}

Flows tested:     N
Flows manual:     N

Unit tests:       N passed / N failed
Integration:      N passed / N failed

Manual checklists:
  - {absolute_path}/<flow-name>-manual.md
```

---

## Output structure

```
tests/
  fixtures.<ext>               ← generated first, shared by all tests
  unit/
    <mirrors source structure>
  integration/
    test_<flow_name>.<ext>
prompts/flows.md               ← from testability-audit
prompts/critical_paths.md      ← from testability-audit
<flow-name>-manual.md          ← one per untestable flow, alongside flows.md
```

---

## Responsibility split

| Responsibility | `/code-testability-audit` | `/code-app-testing` |
|---|---|---|
| Extract user flows from spec | yes | no |
| Auto-discover flows from source | yes | no |
| Map critical path functions | yes | no |
| Label testability per function | yes | no |
| Generate data fixtures | no | yes |
| Generate unit tests | no | yes |
| Generate integration tests | no | yes |
| Generate manual checklists | no | yes |
| Execute tests and report | no | yes |
