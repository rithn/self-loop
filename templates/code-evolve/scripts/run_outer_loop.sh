#!/usr/bin/env bash
set -euo pipefail

# ── Placeholders substituted at scaffold time ──────────────────────────────
SLUG="{SLUG}"
PROJECT_DIR="{PROJECT_DIR}"
RUN_NAME="{RUN_NAME}"
MAX_ITERATIONS="{MAX_ITERATIONS}"

# ── Logging ────────────────────────────────────────────────────────────────
LOG_DIR="${PROJECT_DIR}/scripts/agent-run-logs/${RUN_NAME}"
mkdir -p "${LOG_DIR}"

MAIN_LOG="${LOG_DIR}/outer_loop.log"

log() {
  local msg="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[${ts}] [OUTER] ${msg}" | tee -a "${MAIN_LOG}"
}

log_detail() {
  echo "$1" | tee -a "${MAIN_LOG}"
}

# ── Run from project root ──────────────────────────────────────────────────
cd "${PROJECT_DIR}"

# Allow claude CLI to run inside an existing Claude Code session
unset CLAUDECODE

log "=========================================="
log "Starting outer loop: RUN_NAME=${RUN_NAME}  MAX_ITERATIONS=${MAX_ITERATIONS}"
log "=========================================="

# ── Main loop ──────────────────────────────────────────────────────────────
for (( ITER=1; ITER<=MAX_ITERATIONS; ITER++ )); do
  log "---------- Iteration ${ITER} / ${MAX_ITERATIONS} ----------"

  # Step 1 — Delete .done sentinel so the loop cannot be stopped mid-iteration
  rm -f "${LOG_DIR}/.done"
  log "Cleared .done sentinel"

  # Step 2 — Run outer loop agent ──────────────────────────────────────────
  OUTER_LOG="${LOG_DIR}/outer_agent_iter_${ITER}.log"
  log "Running outer loop agent → ${OUTER_LOG}"

  OUTER_PROMPT="$(sed \
    "s|{RUN_NAME}|${RUN_NAME}|g; s|{PROJECT_DIR}|${PROJECT_DIR}|g" \
    "${PROJECT_DIR}/prompts/outer_loop_agent.md")"

  claude --dangerously-skip-permissions -p "${OUTER_PROMPT}" \
    > "${OUTER_LOG}" 2>&1 || true

  # Step 3 — Check for OUTER LOOP DONE marker ──────────────────────────────
  if ! grep -q "OUTER LOOP DONE" "${OUTER_LOG}"; then
    log "ERROR: 'OUTER LOOP DONE' marker missing from outer agent output. Aborting."
    exit 1
  fi
  log "Outer loop agent completed successfully"

  # Step 4 — Read Action line ───────────────────────────────────────────────
  ACTION_LINE="$(grep '^Action:' "${OUTER_LOG}" | tail -1 || true)"
  ACTION="$(echo "${ACTION_LINE}" | awk '{print $2}' | tr -d '[:space:]')"
  log "Action: ${ACTION}"

  if [[ "${ACTION}" == "COMPLETE" ]]; then
    log "Action is COMPLETE — outer loop finished after ${ITER} iteration(s)."
    break
  fi

  # Step 5 — Run /code-create-spec in extend mode ──────────────────────────
  SPEC_LOG="${LOG_DIR}/spec_update_iter_${ITER}.log"
  log "Running spec update (extend mode) → ${SPEC_LOG}"

  # Snapshot app_spec.txt before update so we can diff it after
  SPEC_BEFORE="${LOG_DIR}/app_spec_iter_${ITER}_before.txt"
  cp "${PROJECT_DIR}/prompts/app_spec.txt" "${SPEC_BEFORE}" 2>/dev/null || true

  SPEC_CMD_MD="${HOME}/.claude/commands/code-create-spec.md"
  SPEC_BRIEF="${PROJECT_DIR}/prompts/spec_update_brief.md"

  claude --dangerously-skip-permissions -p \
    "$(cat "${SPEC_CMD_MD}")

$(cat "${SPEC_BRIEF}")

Run in Extend Mode. Read existing prompts/app_spec.txt. Find highest TICKET-NNN in prompts/tickets.md and start new tickets from that number + 1. APPEND to prompts/tickets.md — do NOT replace it. Run fully autonomously." \
    > "${SPEC_LOG}" 2>&1 || true
  log "Spec update done"

  # Step 6 — Run /code-build-loop setup ────────────────────────────────────
  BUILD_LOOP_LOG="${LOG_DIR}/build_loop_setup_iter_${ITER}.log"
  log "Running build loop setup → ${BUILD_LOOP_LOG}"

  BUILD_CMD_MD="${HOME}/.claude/commands/code-build-loop.md"

  claude --dangerously-skip-permissions -p \
    "$(cat "${BUILD_CMD_MD}")

Project directory: ${PROJECT_DIR}
Run name: ${RUN_NAME}
Tickets per session: 1
Max retries: 3
Run fully autonomously — do not ask questions." \
    > "${BUILD_LOOP_LOG}" 2>&1 || true
  log "Build loop setup done"

  # Step 7 — Run build+verify loop ─────────────────────────────────────────
  log "Running build+verify loop script"
  bash "${PROJECT_DIR}/scripts/run_build_verify_loop.sh" \
    --builder-prompt "${PROJECT_DIR}/prompts/builder.md" \
    --verifier-prompt "${PROJECT_DIR}/prompts/verifier.md" \
    --tickets "${PROJECT_DIR}/prompts/tickets.md" \
    --run-name "${RUN_NAME}" \
    --max-retries 3 \
    --tickets-per-session 1 \
    2>&1 | tee -a "${LOG_DIR}/build_verify_iter_${ITER}.log" || true
  log "Build+verify loop done"

  # Step 8 — Post-build steps ───────────────────────────────────────────────
  log "Running post_build.sh"
  bash "${PROJECT_DIR}/scripts/post_build.sh" \
    2>&1 | tee -a "${LOG_DIR}/post_build_iter_${ITER}.log" || true
  log "Post-build done"

  # ── Append iteration summary to outer_loop.log ────────────────────────────
  SPEC_DELTA="$(diff "${SPEC_BEFORE}" "${PROJECT_DIR}/prompts/app_spec.txt" 2>/dev/null || echo "(spec snapshot missing or no change)")"
  TICKET_PROGRESS="$(cat "${PROJECT_DIR}/scripts/agent-run-logs/${RUN_NAME}/.ticket_progress" 2>/dev/null || echo "(no ticket progress found)")"
  BUILD_ERRORS="$(grep -i "FAILED\|ERROR\|EXCEPTION" "${LOG_DIR}/build_verify_iter_${ITER}.log" 2>/dev/null | tail -20 || echo "(none)")"
  OUTER_DECISION="$(grep -E "^Action:|OUTER LOOP DONE|reasoning:" "${LOG_DIR}/outer_agent_iter_${ITER}.log" 2>/dev/null | tail -5 || echo "(see outer_agent_iter_${ITER}.log)")"

  log "========== Iteration ${ITER} / ${MAX_ITERATIONS} summary =========="
  log "Action: ${ACTION}"
  log_detail ""
  log_detail "── Outer agent decision ──"
  log_detail "${OUTER_DECISION}"
  log_detail ""
  log_detail "── Spec delta ──"
  log_detail "${SPEC_DELTA}"
  log_detail ""
  log_detail "── Ticket progress ──"
  log_detail "${TICKET_PROGRESS}"
  log_detail ""
  log_detail "── Build errors / failures ──"
  log_detail "${BUILD_ERRORS}"
  log_detail ""
  log "========== End of iteration ${ITER} summary =========="
  log "Iteration ${ITER} complete"
done

log "=========================================="
log "Outer loop finished"
log "=========================================="
