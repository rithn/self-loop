#!/usr/bin/env bash
# =============================================================================
# Build-Verify Agent Loop
#
# Two-agent pipeline per cycle:
#   BUILDER — implements tickets, runs basic verify steps, appends to build_report.md
#   VERIFIER — independently verifies, tests corner cases, commits on pass only
#
# Usage (run from project root):
#   bash scripts/run_build_verify_loop.sh \
#     --builder-prompt prompts/builder.md \
#     --verifier-prompt prompts/verifier.md \
#     --tickets prompts/tickets.md \
#     --run-name <name> \
#     [--max-retries 3] \
#     [--tickets-per-session 2]
#
# Watch live (50k line scrollback):
#   tmux attach -t agent-<run-name>
#
# Stop cleanly between cycles:
#   touch scripts/agent-run-logs/<run-name>/.done
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
BUILDER_PROMPT_FILE=""
VERIFIER_PROMPT_FILE=""
TICKETS_FILE="$PROJECT_DIR/prompts/tickets.md"
RUN_NAME=""
MAX_RETRIES=3
TICKETS_PER_SESSION=2
MAX_RUNTIME=$((10 * 60 * 60))   # 10 hours
START_TIME=$(date +%s)

# ── Parse CLI args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --builder-prompt)      BUILDER_PROMPT_FILE="$2"; shift 2 ;;
        --verifier-prompt)     VERIFIER_PROMPT_FILE="$2"; shift 2 ;;
        --tickets)             TICKETS_FILE="$2"; shift 2 ;;
        --run-name)            RUN_NAME="$2"; shift 2 ;;
        --max-retries)         MAX_RETRIES="$2"; shift 2 ;;
        --tickets-per-session) TICKETS_PER_SESSION="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# ── Validate files & tools ────────────────────────────────────────────────────
[[ -z "$BUILDER_PROMPT_FILE" ]]    && { echo "ERROR: --builder-prompt required"; exit 1; }
[[ -z "$VERIFIER_PROMPT_FILE" ]]   && { echo "ERROR: --verifier-prompt required"; exit 1; }
[[ ! -f "$BUILDER_PROMPT_FILE" ]]  && { echo "ERROR: Not found: $BUILDER_PROMPT_FILE"; exit 1; }
[[ ! -f "$VERIFIER_PROMPT_FILE" ]] && { echo "ERROR: Not found: $VERIFIER_PROMPT_FILE"; exit 1; }
[[ ! -f "$TICKETS_FILE" ]]         && { echo "ERROR: Not found: $TICKETS_FILE"; exit 1; }
command -v tmux    &>/dev/null     || { echo "ERROR: tmux not installed"; exit 1; }
command -v python3 &>/dev/null     || { echo "ERROR: python3 not installed"; exit 1; }

# ── Env var validation ────────────────────────────────────────────────────────
ENV_FILE="$PROJECT_DIR/.env"
ENV_REQUIRED_FILE="$PROJECT_DIR/.env.required"

# Source .env if present
if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

# Check all required vars are set
if [[ -f "$ENV_REQUIRED_FILE" ]]; then
    MISSING_VARS=()
    while IFS= read -r var; do
        [[ -z "$var" || "$var" == \#* ]] && continue
        [[ -z "${!var:-}" ]] && MISSING_VARS+=("$var")
    done < "$ENV_REQUIRED_FILE"

    if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
        echo "════════════════════════════════════════════════"
        echo "  ERROR: Missing required environment variables."
        echo "  Fill in .env.template, save as .env, then retry."
        echo ""
        for v in "${MISSING_VARS[@]}"; do echo "    ✗ $v"; done
        echo "════════════════════════════════════════════════"
        exit 1
    fi
fi

[[ -z "$RUN_NAME" ]] && RUN_NAME="run-$(date '+%Y%m%d-%H%M%S')"

# ── Dirs & state files ────────────────────────────────────────────────────────
LOG_DIR="$SCRIPT_DIR/agent-run-logs/$RUN_NAME"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/loop.log"
BUILD_REPORT="$LOG_DIR/build_report.md"
PROGRESS_FILE="$LOG_DIR/.ticket_progress"
SENTINEL_FILE="$LOG_DIR/.done"
ABANDONED_FILE="$LOG_DIR/abandoned_tickets.md"
TMUX_SESSION="agent-$RUN_NAME"

[[ ! -f "$PROGRESS_FILE" ]] && touch "$PROGRESS_FILE"
if [[ ! -f "$BUILD_REPORT" ]]; then
    printf '# Build Report — %s\nStarted: %s\n\n' \
        "$RUN_NAME" "$(date '+%Y-%m-%d %H:%M:%S')" > "$BUILD_REPORT"
fi

# ── Logging ───────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# ── Helpers ───────────────────────────────────────────────────────────────────
runtime_exceeded() {
    local now; now=$(date +%s)
    (( now - START_TIME >= MAX_RUNTIME ))
}

get_retry_count() {
    local ticket="$1"
    local line
    line=$(grep "^${ticket}:" "$PROGRESS_FILE" 2>/dev/null || echo "")
    if echo "$line" | grep -q "FAILED:"; then
        echo "$line" | grep -oE '[0-9]+$' || echo "0"
    else
        echo "0"
    fi
}

get_ticket_content() {
    local ticket="$1"
    awk "
        /^### ${ticket}:/ { found=1 }
        found && /^---$/ && NR > 1 { exit }
        found { print }
    " "$TICKETS_FILE"
}

abandon_ticket() {
    local ticket="$1"
    mark_ticket "$ticket" "ABANDONED"
    log "⚠⚠⚠ ABANDONED: $ticket exceeded max retries ($MAX_RETRIES). See $ABANDONED_FILE"
    {
        printf '### %s\n' "$ticket"
        printf 'Abandoned after %d failed retries.\n\n' "$MAX_RETRIES"
        printf '**Last notes from build report:**\n'
        grep -A 8 "Tickets:.*$ticket" "$BUILD_REPORT" 2>/dev/null | tail -10 || printf '(no notes found)\n'
        printf '\n---\n\n'
    } >> "$ABANDONED_FILE"
}

get_next_tickets() {
    local count="$1"
    local found=0
    while IFS= read -r ticket; do
        local status retries
        status=$(grep "^${ticket}:" "$PROGRESS_FILE" 2>/dev/null | head -1 || echo "")
        echo "$status" | grep -qE "COMPLETE|SKIPPED|ABANDONED" && continue
        echo "$status" | grep -q  "IN_PROGRESS"                && continue
        if echo "$status" | grep -q "FAILED:"; then
            retries=$(get_retry_count "$ticket")
            if (( retries >= MAX_RETRIES )); then
                abandon_ticket "$ticket"
                continue
            fi
        fi
        echo "$ticket"
        (( ++found >= count )) && break
    done < <(grep -E "^### TICKET-[0-9]+:" "$TICKETS_FILE" \
              | sed 's/^### //' | cut -d':' -f1 \
              | sort -t'-' -k2 -n)
}

mark_ticket() {
    local ticket="$1" status="$2"
    if grep -q "^${ticket}:" "$PROGRESS_FILE" 2>/dev/null; then
        sed -i '' "s|^${ticket}:.*|${ticket}: ${status}|" "$PROGRESS_FILE"
    else
        echo "${ticket}: ${status}" >> "$PROGRESS_FILE"
    fi
}

# ── tmux ──────────────────────────────────────────────────────────────────────
setup_tmux() {
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        log "Reusing tmux session: $TMUX_SESSION"
    else
        tmux new-session -d -s "$TMUX_SESSION" -x 220 -y 50
        tmux set-option -t "$TMUX_SESSION" history-limit 50000
        log "Created tmux session: $TMUX_SESSION (50k line scrollback)"
    fi
    log "Watch with: tmux attach -t $TMUX_SESSION"
}

# ── Run an agent in a dedicated tmux window ───────────────────────────────────
run_agent() {
    local window_name="$1"
    local prompt_content="$2"
    local output_file="$3"

    local prompt_file python_runner done_signal
    prompt_file=$(mktemp "$LOG_DIR/prompt_XXXXXX")
    python_runner=$(mktemp "$LOG_DIR/runner_XXXXXX")
    done_signal="$LOG_DIR/.${window_name}_done"

    rm -f "$done_signal" "$output_file"
    printf '%s' "$prompt_content" > "$prompt_file"

    cat > "$python_runner" << PYEOF
import subprocess, sys, os
prompt_path = '$prompt_file'
output_path = '$output_file'
done_path   = '$done_signal'

with open(prompt_path) as f:
    prompt = f.read()

with open(output_path, 'w') as out:
    r = subprocess.run(
        ['claude', '--dangerously-skip-permissions', '-p', prompt],
        stdout=out,
        stderr=subprocess.STDOUT,
        text=True
    )

with open(output_path) as f:
    print(f.read(), end='')

open(done_path, 'w').close()
os.remove('$prompt_file')
os.remove('$python_runner')
sys.exit(r.returncode)
PYEOF

    tmux kill-window -t "$TMUX_SESSION:$window_name" 2>/dev/null || true
    tmux new-window -t "$TMUX_SESSION" -n "$window_name"
    tmux send-keys -t "$TMUX_SESSION:$window_name" \
        "python3 '$python_runner'" \
        Enter

    log "[$window_name] Started. (tmux attach -t $TMUX_SESSION)"

    while [[ ! -f "$done_signal" ]]; do
        if runtime_exceeded; then
            log "[$window_name] Max runtime hit while waiting."
            rm -f "$prompt_file" "$python_runner" "$done_signal"
            return 1
        fi
        sleep 3
    done

    rm -f "$done_signal"
    log "[$window_name] Finished."
    return 0
}

# ── Signal handling ───────────────────────────────────────────────────────────
cleanup() {
    echo ""
    log "Interrupted. Saving state..."
    sed -i '' 's/: IN_PROGRESS$/: INTERRUPTED/' "$PROGRESS_FILE" 2>/dev/null || true
    log "Progress saved: $PROGRESS_FILE"
    exit 1
}
trap cleanup INT TERM

# ══ MAIN ══════════════════════════════════════════════════════════════════════
CYCLE=0

log "════════════════════════════════════════════════"
log "  Build-Verify Loop — $RUN_NAME"
log "  Builder:  $BUILDER_PROMPT_FILE"
log "  Verifier: $VERIFIER_PROMPT_FILE"
log "  Tickets:  $TICKETS_FILE"
log "  Logs:     $LOG_DIR"
log "  Stop:     touch $SENTINEL_FILE"
log "════════════════════════════════════════════════"

setup_tmux

while true; do
    CYCLE=$((CYCLE + 1))
    log "══ Cycle $CYCLE ══"

    [[ -f "$SENTINEL_FILE" ]] && { log "Sentinel detected. Stopping."; break; }
    runtime_exceeded          && { log "Max runtime exceeded. Stopping."; break; }

    TICKETS=()
    while IFS= read -r t; do
        [[ -n "$t" ]] && TICKETS+=("$t")
    done < <(get_next_tickets "$TICKETS_PER_SESSION")

    if [[ ${#TICKETS[@]} -eq 0 ]]; then
        log "No more tickets to process. All done."
        touch "$SENTINEL_FILE"
        break
    fi

    TICKET_LABELS="${TICKETS[*]}"
    log "Tickets this cycle: $TICKET_LABELS"
    for t in "${TICKETS[@]}"; do mark_ticket "$t" "IN_PROGRESS"; done

    TICKET_BODIES=""
    for t in "${TICKETS[@]}"; do
        TICKET_BODIES+="$(get_ticket_content "$t")"$'\n\n'
    done

    CYCLE_TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"

    # ── BUILDER ───────────────────────────────────────────────────────────────
    BUILDER_PROMPT="$(cat "$BUILDER_PROMPT_FILE")

## Tickets to Implement This Cycle

$TICKET_BODIES

## Prior Build Report (context from all previous cycles)

$(cat "$BUILD_REPORT")

## Current Ticket Progress State

$(cat "$PROGRESS_FILE")

## Project Directory

$PROJECT_DIR

## Output Contract

After finishing all tickets, append the following block to $BUILD_REPORT (use exactly this format):

---
### Cycle $CYCLE — Builder — $CYCLE_TIMESTAMP
**Tickets:** $TICKET_LABELS
**Results:** <TICKET-XXX: PASS/FAIL, TICKET-XXX: PASS/FAIL>
**Notes:** <what you implemented, what failed, errors observed, anything the verifier should know>
---

Then output exactly one of these lines as the final line of your response:
BUILD DONE: COMPLETE
BUILD DONE: PARTIAL
BUILD DONE: FAILED
"

    BUILDER_OUT="$LOG_DIR/builder_cycle_${CYCLE}.log"
    if ! run_agent "builder-c${CYCLE}" "$BUILDER_PROMPT" "$BUILDER_OUT"; then
        log "Builder did not complete. Marking INTERRUPTED."
        for t in "${TICKETS[@]}"; do mark_ticket "$t" "INTERRUPTED"; done
        break
    fi

    BUILDER_RESULT=$(grep "^BUILD DONE:" "$BUILDER_OUT" 2>/dev/null | tail -1 | sed 's/^BUILD DONE: //' || echo "")
    log "Builder result: '${BUILDER_RESULT:-no marker found}'"

    if [[ "$BUILDER_RESULT" == "FAILED" || -z "$BUILDER_RESULT" ]]; then
        log "Builder failed or did not output marker. Incrementing retry count."
        for t in "${TICKETS[@]}"; do
            retries=$(get_retry_count "$t")
            mark_ticket "$t" "FAILED:$((retries + 1))"
        done
        sleep 2
        continue
    fi

    # ── VERIFIER ──────────────────────────────────────────────────────────────
    VERIFIER_PROMPT="$(cat "$VERIFIER_PROMPT_FILE")

## Tickets to Verify

$TICKET_BODIES

## Full Build Report (includes builder's notes for this cycle at the bottom)

$(cat "$BUILD_REPORT")

## Project Directory

$PROJECT_DIR

## Output Contract

After verification, append the following block to $BUILD_REPORT (use exactly this format):

---
### Cycle $CYCLE — Verifier — $CYCLE_TIMESTAMP
**Tickets:** $TICKET_LABELS
**Results:** <TICKET-XXX: PASS/FAIL, TICKET-XXX: PASS/FAIL>
**Corner cases tested:** <list what you tested beyond the basic verify steps>
**Notes:** <specific failure details if any — this will be read by the builder on the next retry>
---

If ALL tickets pass verification:
  1. Run: git add -A && git commit -m 'Implement $TICKET_LABELS'
  2. Output exactly: VERIFY DONE: PASS

If ANY ticket fails:
  - Do NOT run git commit
  - Output exactly: VERIFY DONE: FAIL
"

    VERIFIER_OUT="$LOG_DIR/verifier_cycle_${CYCLE}.log"
    if ! run_agent "verifier-c${CYCLE}" "$VERIFIER_PROMPT" "$VERIFIER_OUT"; then
        log "Verifier did not complete. Marking INTERRUPTED."
        for t in "${TICKETS[@]}"; do mark_ticket "$t" "INTERRUPTED"; done
        break
    fi

    VERIFY_RESULT=$(grep "^VERIFY DONE:" "$VERIFIER_OUT" 2>/dev/null | tail -1 | sed 's/^VERIFY DONE: //' || echo "")
    log "Verifier result: '${VERIFY_RESULT:-no marker found}'"

    if [[ "$VERIFY_RESULT" == "PASS" ]]; then
        log "Verified and committed: $TICKET_LABELS"
        for t in "${TICKETS[@]}"; do mark_ticket "$t" "COMPLETE"; done
    else
        log "Verification failed. Incrementing retry count for: $TICKET_LABELS"
        for t in "${TICKETS[@]}"; do
            retries=$(get_retry_count "$t")
            mark_ticket "$t" "FAILED:$((retries + 1))"
        done
    fi

    sleep 2
done

# ── Final summary ─────────────────────────────────────────────────────────────
log "════════════════════════════════════════════════"
log "Loop finished. Final progress:"
cat "$PROGRESS_FILE" | tee -a "$LOG_FILE"
log "Logs at: $LOG_DIR"

ABANDONED_COUNT=$(grep -c ": ABANDONED" "$PROGRESS_FILE" 2>/dev/null || echo "0")
if (( ABANDONED_COUNT > 0 )); then
    log ""
    log "⚠⚠⚠  $ABANDONED_COUNT ticket(s) were ABANDONED after exceeding max retries."
    log "      Review: $ABANDONED_FILE"
    log "════════════════════════════════════════════════"
    exit 1
fi

log "════════════════════════════════════════════════"
