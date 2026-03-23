# App Testing Skill — Flow Design

## Overview

Takes the outputs of the `testability-audit` skill and produces a full test suite. Handles unit tests, integration tests, and manual checklists for flows that can't be tested programmatically.

Framework is auto-detected from the implementation language:
- Python → pytest
- JavaScript / TypeScript → jest
- Go → go test
- Ruby → rspec

If multiple languages are present, a framework is selected per-language.

---

## Prerequisites

This skill expects the following files produced by `testability-audit`:

- `flows.md` — confirmed list of all user flows
- `critical_paths.md` — functions per flow with testability labels (`unit`, `integration`, `cli`, `untestable`)

If these files don't exist, the skill invokes `testability-audit` automatically before proceeding.

All file paths used by this skill are absolute to ensure the skill works from any working directory.

---

## Fix 1 — Real Calls vs Mocks (ask upfront)

Before generating any tests, ask the user:

> "Should tests use **real API calls** for external services (OpenAI, payment APIs, etc.) or **mocks**? Default is real calls with a skip guard if the key is absent."

**Real calls (default):** mark tests that require external services with a skip guard (e.g. `@pytest.mark.live_llm`) that skips if the required env var is unset. For every such function, generate at least one known-bad → must produce output test (see Fix 2 in Phase 2).

**Mocks:** proceed with standard mocking; document the strategy in a comment in `tests/fixtures.<ext>`.

---

## Phase 1: Data Fixtures

**Action:** Before writing any tests, scan `critical_paths.md` for all data entities referenced across flows.

Generate `tests/fixtures.<ext>` containing:
- One factory function per entity (e.g. `user_factory()`, `project_factory()`, `order_factory()`)
- Each factory creates a minimal valid instance with sensible defaults
- Parameters allow field-level overrides for specific test scenarios
- Each factory handles its own teardown / cleanup

**Self-containment rule — enforced for every test without exception:**
- Every test sets up all state it needs via these factories
- No test may rely on state created by another test
- No test may assume a specific execution order
- If a test needs a logged-in user, it creates that user itself — it does not reuse one from a prior test

All subsequent test files import from this file rather than defining inline setup.

**Fix 3 — Env var guard in `conftest.py`:**
Add a session-scoped fixture that reads `.env.required` (if it exists) and asserts every listed variable is set before any test runs. Fail immediately with a clear list of missing vars:
```python
@pytest.fixture(scope="session", autouse=True)
def check_required_env_vars():
    env_required = Path(".env.required")
    if not env_required.exists():
        return
    missing = [
        v for v in env_required.read_text().splitlines()
        if v and not v.startswith("#") and not os.getenv(v)
    ]
    if missing:
        pytest.exit(f"Missing required env vars: {', '.join(missing)}. Fill .env and retry.", returncode=1)
```

**Fix 4 — Server preflight in integration `conftest.py`:**
Add a session-scoped fixture that makes a real HTTP call to a known endpoint before integration tests start. Exit immediately on connection failure or unexpected status:
```python
@pytest.fixture(scope="session", autouse=True)
def server_preflight():
    try:
        r = httpx.get("http://localhost:8000/", timeout=5)
        assert r.status_code < 500, f"Server returned {r.status_code} — check routes and restart"
    except Exception as e:
        pytest.exit(f"Server not reachable: {e}. Start the server before running integration tests.", returncode=1)
```
Place only in the integration `conftest.py`, not the unit one.

---

## Phase 2: Unit Test Generation

**Action:** Only test functions that appear directly in `critical_paths.md`. Do not test internal helpers or utilities not on a flow's call chain.

Test behaviour from the caller's perspective — not internal implementation details. If `create_project()` is on the critical path, assert on its return value and side effects, not on whether it internally calls `validate_project()`.

For each qualifying function:
- Write tests covering:
  - Happy path
  - Edge cases (empty input, boundary values, null/None)
  - Known failure modes (invalid input, missing dependencies)
- Use factories from `tests/fixtures.<ext>` for any required data
- Place tests under `tests/unit/`, mirroring the source directory structure

**Fix 2 — AI validator test rule:**
For every function that calls an external AI/LLM service, generate:
1. At least one **known-bad → must produce output** test: an input known to trigger a non-empty result, asserting `len(result) >= 1`. A validator that silently returns `[]` for all inputs will pass naive tests — this catches that.
2. At least one **clean input → no output** test confirming the validator stays quiet on valid data.
Mark both with a skip guard (e.g. `@pytest.mark.live_llm`) that skips if the API key env var is absent.

```python
@pytest.mark.live_llm
def test_validator_warns_for_known_bad_input():
    issues = validate_step_ai(known_bad_payload)
    assert len(issues) >= 1, "Expected ≥1 warning for known problematic input"
    assert all(i.level == "warning" for i in issues)

@pytest.mark.live_llm
def test_validator_silent_for_clean_input():
    issues = validate_step_ai(clean_payload)
    assert issues == []
```

---

## Phase 3: Integration Test Generation

**Action:** For each user flow where all functions are testable:

- Write one test file exercising the full flow end-to-end
- Use factories from `tests/fixtures.<ext>` for all state — tests must be self-contained
- Use `curl`, HTTP clients, or direct function calls as appropriate
- Place under `tests/integration/test_<flow_name>.<ext>`

**Assertion rule:** Every integration test must assert on response body content or a state change — never on status code alone. If the only observable outcome is a status code, flag the test as `[shallow]` and note what state evidence is missing.

**AI validators in integration tests:** For any flow that includes an AI validation step, include a live integration test class (`@pytest.mark.live_llm`) that hits the running server directly:
1. Submit a payload known to trigger AI warnings → assert warnings present in response body
2. Submit a clean payload → assert no blocking errors in response body
No mocks — these must exercise the real validator via real HTTP.

---

## Phase 4: Manual Test Checklists

**Action:** For every flow containing at least one `untestable` function:

- Generate `<flow-name>-manual.md` in the same directory as `flows.md`
- Contents:
  - What the flow does
  - Pre-conditions
  - Step-by-step instructions for a human tester
  - Expected outcome at each step
  - Which functions are untestable and why

---

## Phase 5: Test Execution

**Stage 1 — All unit tests, run globally:**
```
pytest tests/unit/ -v
```
Fix all failures before proceeding. Do not move to integration tests until unit suite is fully green.

**Stage 2 — Integration tests, run sequentially per flow:**

For each flow in order:
1. Run its integration test
2. Report pass / fail immediately
3. On failure: diagnose, fix, re-run, confirm green — then move to the next flow

Manual-only flows: print the absolute path to the checklist file and skip.

After all flows are processed, print a summary:
- Pass / fail counts for unit and integration
- List of manual-only flows with absolute paths to their checklist files

---

## Directory Structure

```
tests/
  fixtures.<ext>               ← generated first, shared by all tests
  unit/
    <mirrors source structure>
  integration/
    test_<flow_name>.<ext>
flows.md                       ← produced by testability-audit (absolute path)
critical_paths.md              ← produced by testability-audit (absolute path)
<flow-name>-manual.md          ← one per untestable flow, alongside flows.md
```

---

## Responsibility Split

| Responsibility | testability-audit | app-testing |
|---|---|---|
| Intake spec / docs | yes | no |
| Extract user flows from spec | yes | no |
| Auto-discover flows from source | yes | no |
| User confirmation of flow coverage | yes | no |
| Map critical path functions | yes | no |
| Label testability per function | yes | no |
| Generate data fixtures | no | yes |
| Generate unit tests | no | yes |
| Generate integration tests | no | yes |
| Generate manual checklists | no | yes |
| Execute tests and report | no | yes |

---

## Decisions

| Decision | Choice |
|---|---|
| Framework selection | Auto-detected from implementation language |
| Real vs mock for external services | Ask upfront — default real with skip guard |
| AI validator tests | Always: known-bad → must warn + clean → silent |
| Env var guard | Session fixture in conftest.py reading .env.required |
| Server preflight | Session fixture in integration conftest.py — fail fast |
| Data fixtures | Generated before tests, shared factory file |
| Unit test execution | All at once globally, must be green before integration |
| Integration test execution | Sequential per flow, fix before advancing |
