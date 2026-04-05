#!/usr/bin/env bash
set -uo pipefail

# ── Placeholders substituted at scaffold time ──────────────────────────────
PROJECT_DIR="{PROJECT_DIR}"
RUN_NAME="{RUN_NAME}"

# ── Logging ────────────────────────────────────────────────────────────────
LOG_DIR="${PROJECT_DIR}/scripts/agent-run-logs/${RUN_NAME}/post-build-logs"
mkdir -p "${LOG_DIR}"

log() {
  local msg="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[${ts}] [POST-BUILD] ${msg}" | tee -a "${LOG_DIR}/post_build.log"
}

log "=========================================="
log "Starting post-build sequence"
log "=========================================="

# ── Step 1 — Testability audit ─────────────────────────────────────────────
log "Step 1: Testability audit"

AUDIT_CMD="${HOME}/.claude/commands/code-testability-audit.md"
AUDIT_LOG="${LOG_DIR}/testability_audit.log"

claude --dangerously-skip-permissions -p \
  "$(cat "${AUDIT_CMD}")

Project directory: ${PROJECT_DIR}
Run autonomously — confirm all flows without asking user for confirmation.

After completing all steps, output exactly on its own line: AUDIT DONE" \
  > "${AUDIT_LOG}" 2>&1 || true

if grep -q "AUDIT DONE" "${AUDIT_LOG}"; then
  log "Testability audit: DONE"
else
  log "WARNING: 'AUDIT DONE' marker missing from testability audit output"
fi

# ── Step 2 — App testing ───────────────────────────────────────────────────
log "Step 2: App testing"

APP_CMD="${HOME}/.claude/commands/code-app-testing.md"
APP_LOG="${LOG_DIR}/app_testing.log"

claude --dangerously-skip-permissions -p \
  "$(cat "${APP_CMD}")

Project directory: ${PROJECT_DIR}
Run autonomously. Use real API calls with skip guards if keys absent.

After completing all steps, output exactly on its own line: APP TESTING DONE" \
  > "${APP_LOG}" 2>&1 || true

if grep -q "APP TESTING DONE" "${APP_LOG}"; then
  log "App testing: DONE"
else
  log "WARNING: 'APP TESTING DONE' marker missing from app testing output"
fi

# ── Step 3 — UI testing ────────────────────────────────────────────────────
log "Step 3: UI testing"

UI_CMD="${HOME}/.claude/commands/code-ui-testing.md"
UI_LOG="${LOG_DIR}/ui_testing.log"

# Start uvicorn
log "Starting uvicorn server on port 8000"
cd "${PROJECT_DIR}"
# shellcheck disable=SC1091
source .env 2>/dev/null || true
uv run uvicorn app.main:app --port 8000 --host 0.0.0.0 &
SERVER_PID=$!
log "Server PID: ${SERVER_PID}"

sleep 5

# Run UI testing agent
claude --dangerously-skip-permissions -p \
  "$(cat "${UI_CMD}")

App running at http://localhost:8000. Project directory: ${PROJECT_DIR}.

After completing all steps, output exactly on its own line: UI TESTING DONE" \
  > "${UI_LOG}" 2>&1 || true

# Kill server
log "Stopping uvicorn server (PID ${SERVER_PID})"
kill "${SERVER_PID}" 2>/dev/null || true

if grep -q "UI TESTING DONE" "${UI_LOG}"; then
  log "UI testing: DONE"
else
  log "WARNING: 'UI TESTING DONE' marker missing from UI testing output"
fi

log "=========================================="
log "Post-build sequence complete"
log "=========================================="

exit 0
