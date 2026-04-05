#!/usr/bin/env bash
set -uo pipefail

# ── Placeholders substituted at scaffold time ──────────────────────────────
SLUG="{SLUG}"
PROJECT_DIR="{PROJECT_DIR}"
RUN_NAME="{RUN_NAME}"

# ── Default thresholds ─────────────────────────────────────────────────────
CHECK_INTERVAL=600
STUCK_THRESHOLD=1800

# ── Parse CLI arguments ────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-interval)
      CHECK_INTERVAL="$2"
      shift 2
      ;;
    --stuck-threshold)
      STUCK_THRESHOLD="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# ── Paths ──────────────────────────────────────────────────────────────────
STOP_FILE="${PROJECT_DIR}/scripts/heartbeat.stop"
OUTER_LOG="${PROJECT_DIR}/scripts/agent-run-logs/${RUN_NAME}/outer_loop.log"
HB_LOG="${PROJECT_DIR}/scripts/agent-run-logs/${RUN_NAME}/heartbeat.log"

mkdir -p "$(dirname "${HB_LOG}")"

# ── Logging ────────────────────────────────────────────────────────────────
log() {
  local msg="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[${ts}] [HEARTBEAT] ${msg}" | tee -a "${HB_LOG}"
}

log "Heartbeat started — check-interval=${CHECK_INTERVAL}s  stuck-threshold=${STUCK_THRESHOLD}s"

# ── Main loop ──────────────────────────────────────────────────────────────
while true; do

  # Check stop file
  if [[ -f "${STOP_FILE}" ]]; then
    log "Stop file found at ${STOP_FILE} — exiting"
    exit 0
  fi

  # Check outer loop log existence
  if [[ ! -f "${OUTER_LOG}" ]]; then
    log "Waiting for outer loop to start (${OUTER_LOG} not found yet)"
    sleep "${CHECK_INTERVAL}"
    continue
  fi

  # Read last line and parse timestamp
  LAST_LINE="$(tail -1 "${OUTER_LOG}" 2>/dev/null || true)"

  # Extract timestamp — expected format: [YYYY-MM-DD HH:MM:SS]
  LAST_TS_STR="$(echo "${LAST_LINE}" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1 || true)"

  if [[ -z "${LAST_TS_STR}" ]]; then
    log "Could not parse timestamp from last log line — skipping this check"
    sleep "${CHECK_INTERVAL}"
    continue
  fi

  # Convert to epoch seconds
  LAST_EPOCH="$(date -j -f '%Y-%m-%d %H:%M:%S' "${LAST_TS_STR}" '+%s' 2>/dev/null \
    || date -d "${LAST_TS_STR}" '+%s' 2>/dev/null \
    || echo 0)"
  NOW_EPOCH="$(date '+%s')"
  ELAPSED=$(( NOW_EPOCH - LAST_EPOCH ))
  ELAPSED_MIN=$(( ELAPSED / 60 ))

  if (( ELAPSED > STUCK_THRESHOLD )); then
    log "STUCK: last activity ${ELAPSED_MIN} min ago — restarting outer loop"

    # Kill existing tmux session
    tmux kill-session -t "agent-${SLUG}" 2>/dev/null || true
    log "Killed tmux session agent-${SLUG}"

    sleep 5

    # Restart in new tmux session
    tmux new-session -d -s "agent-${SLUG}" -x 220 -y 50
    tmux send-keys -t "agent-${SLUG}" \
      "bash ${PROJECT_DIR}/scripts/run_outer_loop.sh" Enter
    log "Restarted outer loop in tmux session agent-${SLUG}"
  else
    log "OK: last activity ${ELAPSED} seconds ago"
  fi

  sleep "${CHECK_INTERVAL}"
done
