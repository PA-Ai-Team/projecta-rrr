#!/bin/bash
#
# Pushpa Mode - Token-Safe Overnight Runner for RRR
# Runs plan+execute phases with hard budgets and persistent ledger
#
# Usage: bash scripts/pushpa-mode.sh
#
# Requirements:
# - MVP_FEATURES.yml must exist (./MVP_FEATURES.yml or .planning/MVP_FEATURES.yml)
# - Required API keys must be set based on your feature selections
# - Claude Code must be installed and configured
# - Project must be initialized (.planning/STATE.md or .planning/ROADMAP.md)
#
# Budgets (env vars, defaults shown):
# - MAX_PHASES_PER_RUN=3         Max phases to process in one run
# - MAX_TOTAL_MINUTES=180        Max total runtime (3 hours)
# - MAX_TOTAL_RRR_CALLS=25       Max /rrr:* invocations (token proxy)
# - MAX_PLAN_ATTEMPTS_PER_PHASE=2
# - MAX_EXEC_ATTEMPTS_PER_PHASE=2
# - MAX_CONSECUTIVE_FAILURES=3
# - MAX_SAME_FAILURE_REPEAT=2    Stop if same failure signature repeats
# - BACKOFF_SECONDS=10           Initial backoff (increases: 10,30,60)
#
# Stop conditions (hard exits):
# - Any budget exceeded
# - Same failure signature repeats >= MAX_SAME_FAILURE_REPEAT
# - Consecutive failures >= MAX_CONSECUTIVE_FAILURES
# - No progress for 30 minutes
# - Git conflicts detected
# - Missing required env vars (and user declines)
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Budgets (overrideable via env vars)
# ═══════════════════════════════════════════════════════════════════════════════

MAX_PHASES_PER_RUN="${MAX_PHASES_PER_RUN:-3}"
MAX_TOTAL_MINUTES="${MAX_TOTAL_MINUTES:-180}"
MAX_TOTAL_RRR_CALLS="${MAX_TOTAL_RRR_CALLS:-25}"
MAX_PLAN_ATTEMPTS_PER_PHASE="${MAX_PLAN_ATTEMPTS_PER_PHASE:-2}"
MAX_EXEC_ATTEMPTS_PER_PHASE="${MAX_EXEC_ATTEMPTS_PER_PHASE:-2}"
MAX_CONSECUTIVE_FAILURES="${MAX_CONSECUTIVE_FAILURES:-3}"
MAX_SAME_FAILURE_REPEAT="${MAX_SAME_FAILURE_REPEAT:-2}"
BACKOFF_SECONDS="${BACKOFF_SECONDS:-10}"

# ═══════════════════════════════════════════════════════════════════════════════
# Paths
# ═══════════════════════════════════════════════════════════════════════════════

PLANNING_DIR=".planning"
PHASES_DIR="$PLANNING_DIR/phases"
PUSHPA_DIR="$PLANNING_DIR/pushpa"
LOGS_DIR="$PLANNING_DIR/logs"
ARTIFACTS_DIR="$PLANNING_DIR/artifacts"
STATE_FILE="$PLANNING_DIR/STATE.md"
ROADMAP_FILE="$PLANNING_DIR/ROADMAP.md"
REPORT_FILE="$PLANNING_DIR/PUSHPA_REPORT.md"
LEDGER_FILE="$PUSHPA_DIR/ledger.json"
VISUAL_PROOF_FILE="$PLANNING_DIR/VISUAL_PROOF.md"

# MVP_FEATURES.yml path resolution
FEATURES_FILE=""
if [ -f "./MVP_FEATURES.yml" ]; then
    FEATURES_FILE="./MVP_FEATURES.yml"
elif [ -f "$PLANNING_DIR/MVP_FEATURES.yml" ]; then
    FEATURES_FILE="$PLANNING_DIR/MVP_FEATURES.yml"
fi

# HITL markers
HITL_MARKERS=("HITL_REQUIRED: true" "HUMAN_VERIFICATION_REQUIRED" "MANUAL_VERIFICATION")

# ═══════════════════════════════════════════════════════════════════════════════
# Pushpa Mode Environment Flag
# ═══════════════════════════════════════════════════════════════════════════════
# Export PUSHPA_MODE so downstream scripts know they're running unattended.
# This flag is checked by:
# - scripts/chrome-visual-check.sh (MUST skip - requires human interaction)
# - scripts/visual-proof.sh (runs headless only, never interactive)
# - execute-plan/execute-phase (skips chrome_visual_check step)
export PUSHPA_MODE=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# Ledger Management
# ═══════════════════════════════════════════════════════════════════════════════

RUN_ID=""
START_TIME=""
LOG_FILE=""

init_ledger() {
    mkdir -p "$PUSHPA_DIR" "$LOGS_DIR"

    START_TIME=$(date +%s)
    RUN_ID=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="$LOGS_DIR/pushpa_${RUN_ID}.log"
    touch "$LOG_FILE"

    if [ ! -f "$LEDGER_FILE" ]; then
        # Create new ledger
        cat > "$LEDGER_FILE" << EOF
{
  "run_id": "$RUN_ID",
  "started_at": "$(date -Iseconds)",
  "total_rrr_calls": 0,
  "total_minutes_elapsed": 0,
  "consecutive_failures": 0,
  "phases_completed": 0,
  "last_failure_signature": "",
  "same_failure_count": 0,
  "phases": {}
}
EOF
        log INFO "Created new ledger: $LEDGER_FILE"
    else
        # Resume from existing ledger
        log INFO "Resuming from existing ledger: $LEDGER_FILE"
        # Update run_id for this session
        update_ledger_field "run_id" "$RUN_ID"
    fi
}

read_ledger_field() {
    local field="$1"
    grep -o "\"$field\"[[:space:]]*:[[:space:]]*[^,}]*" "$LEDGER_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '"' || echo ""
}

read_ledger_int() {
    local field="$1"
    local value
    value=$(read_ledger_field "$field")
    echo "${value:-0}" | tr -d ' '
}

update_ledger_field() {
    local field="$1"
    local value="$2"

    # Use a temp file for atomic update
    local temp_file="$LEDGER_FILE.tmp"

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        # Numeric value
        sed "s/\"$field\"[[:space:]]*:[[:space:]]*[0-9]*/\"$field\": $value/" "$LEDGER_FILE" > "$temp_file"
    else
        # String value
        sed "s/\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"$field\": \"$value\"/" "$LEDGER_FILE" > "$temp_file"
    fi

    mv "$temp_file" "$LEDGER_FILE"
}

increment_ledger() {
    local field="$1"
    local current
    current=$(read_ledger_int "$field")
    local new_value=$((current + 1))
    update_ledger_field "$field" "$new_value"
    echo "$new_value"
}

update_elapsed_time() {
    local now
    now=$(date +%s)
    local elapsed=$(( (now - START_TIME) / 60 ))
    update_ledger_field "total_minutes_elapsed" "$elapsed"
    echo "$elapsed"
}

record_failure() {
    local signature="$1"

    # Increment consecutive failures
    increment_ledger "consecutive_failures"

    # Check if same failure
    local last_sig
    last_sig=$(read_ledger_field "last_failure_signature")

    if [ "$last_sig" = "$signature" ]; then
        increment_ledger "same_failure_count"
    else
        update_ledger_field "last_failure_signature" "$signature"
        update_ledger_field "same_failure_count" "1"
    fi
}

reset_consecutive_failures() {
    update_ledger_field "consecutive_failures" "0"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Budget Checks
# ═══════════════════════════════════════════════════════════════════════════════

STOP_REASON=""

check_budgets() {
    local rrr_calls
    rrr_calls=$(read_ledger_int "total_rrr_calls")
    local elapsed
    elapsed=$(update_elapsed_time)
    local consec_failures
    consec_failures=$(read_ledger_int "consecutive_failures")
    local same_failure_count
    same_failure_count=$(read_ledger_int "same_failure_count")
    local phases_completed
    phases_completed=$(read_ledger_int "phases_completed")

    # Check total RRR calls
    if [ "$rrr_calls" -ge "$MAX_TOTAL_RRR_CALLS" ]; then
        STOP_REASON="BUDGET_EXCEEDED: total_rrr_calls ($rrr_calls >= $MAX_TOTAL_RRR_CALLS)"
        return 1
    fi

    # Check elapsed time
    if [ "$elapsed" -ge "$MAX_TOTAL_MINUTES" ]; then
        STOP_REASON="BUDGET_EXCEEDED: total_minutes ($elapsed >= $MAX_TOTAL_MINUTES)"
        return 1
    fi

    # Check consecutive failures
    if [ "$consec_failures" -ge "$MAX_CONSECUTIVE_FAILURES" ]; then
        STOP_REASON="BUDGET_EXCEEDED: consecutive_failures ($consec_failures >= $MAX_CONSECUTIVE_FAILURES)"
        return 1
    fi

    # Check same failure repeat
    if [ "$same_failure_count" -ge "$MAX_SAME_FAILURE_REPEAT" ]; then
        STOP_REASON="BUDGET_EXCEEDED: same_failure_repeat ($same_failure_count >= $MAX_SAME_FAILURE_REPEAT)"
        return 1
    fi

    # Check phases per run
    if [ "$phases_completed" -ge "$MAX_PHASES_PER_RUN" ]; then
        STOP_REASON="BUDGET_EXCEEDED: phases_per_run ($phases_completed >= $MAX_PHASES_PER_RUN)"
        return 1
    fi

    return 0
}

check_git_conflicts() {
    if git status 2>/dev/null | grep -q "both modified\|Unmerged paths"; then
        STOP_REASON="GIT_CONFLICTS: Merge conflicts detected"
        return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Logging
# ═══════════════════════════════════════════════════════════════════════════════

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        INFO)  echo -e "${CYAN}[$level]${NC} $message" ;;
        OK)    echo -e "${GREEN}[$level]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[$level]${NC} $message" ;;
        ERROR) echo -e "${RED}[$level]${NC} $message" ;;
        SKIP)  echo -e "${YELLOW}[SKIP]${NC} $message" ;;
        STOP)  echo -e "${RED}[STOP]${NC} $message" ;;
        *)     echo "[$level] $message" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# Claude Code Detection
# ═══════════════════════════════════════════════════════════════════════════════

detect_claude_code() {
    # Check Claude-related environment variables
    if [ -n "${CLAUDE:-}" ] || [ -n "${CLAUDE_CODE:-}" ] || [ -n "${ANTHROPIC:-}" ]; then
        return 0
    fi
    if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
        return 0
    fi

    # Check for any CLAUDE_* or ANTHROPIC_* env vars (pattern match)
    if env | grep -qiE "^CLAUDE_|^ANTHROPIC_"; then
        return 0
    fi

    # Check if running in Claude Code's terminal (session marker)
    if [ -n "${CLAUDE_SESSION_ID:-}" ] || [ -n "${CLAUDE_WORKSPACE:-}" ]; then
        return 0
    fi

    # Check parent process name for "claude"
    local parent_name=""
    parent_name=$(ps -o comm= -p "$PPID" 2>/dev/null || echo "")
    if echo "$parent_name" | grep -qi "claude"; then
        return 0
    fi

    # Check grandparent process name for "claude"
    local grandparent_pid=""
    grandparent_pid=$(ps -o ppid= -p "$PPID" 2>/dev/null | tr -d ' ' || echo "")
    if [ -n "$grandparent_pid" ] && [ "$grandparent_pid" != "1" ]; then
        local grandparent_name=""
        grandparent_name=$(ps -o comm= -p "$grandparent_pid" 2>/dev/null || echo "")
        if echo "$grandparent_name" | grep -qi "claude"; then
            return 0
        fi
    fi

    # Check process tree for claude (up to 5 levels)
    local current_pid="$$"
    local depth=0
    while [ "$depth" -lt 5 ] && [ -n "$current_pid" ] && [ "$current_pid" != "1" ]; do
        local proc_name=""
        proc_name=$(ps -o comm= -p "$current_pid" 2>/dev/null || echo "")
        if echo "$proc_name" | grep -qi "claude"; then
            return 0
        fi
        current_pid=$(ps -o ppid= -p "$current_pid" 2>/dev/null | tr -d ' ' || echo "")
        depth=$((depth + 1))
    done

    # Check VS Code with Claude extension active
    if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
        if [ -n "${VSCODE_GIT_IPC_HANDLE:-}" ]; then
            local ps_output=""
            ps_output=$(ps -e 2>/dev/null | grep -i "claude" || echo "")
            if [ -n "$ps_output" ]; then
                return 0
            fi
        fi
    fi

    return 1
}

check_claude_code_environment() {
    if detect_claude_code; then
        echo ""
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}  ⚠ DETECTED: Running inside Claude Code terminal${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "   Pushpa Mode is designed for unattended overnight execution."
        echo "   Running inside Claude Code's interactive session can:"
        echo "   - Trigger permission approval prompts"
        echo "   - Be interrupted by context window resets"
        echo "   - Not run truly unattended"
        echo ""
        echo -e "${GREEN}RECOMMENDED:${NC} Run in a separate terminal window"
        echo ""
        echo "   1. Open a new system terminal (Terminal.app, iTerm, etc.)"
        echo "   2. Navigate to your project:"
        echo -e "      ${CYAN}cd $(pwd)${NC}"
        echo "   3. Run Pushpa Mode:"
        echo -e "      ${CYAN}bash scripts/pushpa-mode.sh${NC}"
        echo ""

        read -r -p "Continue anyway inside Claude Code? (y/N): " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${GREEN}Good choice!${NC} Exiting Pushpa Mode."
            echo ""
            echo "To run Pushpa Mode properly, copy and paste these commands"
            echo "into a new terminal window:"
            echo ""
            echo -e "  ${CYAN}cd $(pwd)${NC}"
            echo -e "  ${CYAN}bash scripts/pushpa-mode.sh${NC}"
            echo ""
            exit 0
        fi
        echo ""
        echo -e "${YELLOW}Continuing inside Claude Code (user confirmed)...${NC}"
        echo ""
    else
        echo -e "${GREEN}✓ Running in standard terminal (recommended for Pushpa Mode)${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Banner
# ═══════════════════════════════════════════════════════════════════════════════

print_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}"
    echo "+-------------------------------------------------------------------+"
    echo "|                                                                   |"
    echo "|   PUSHPA MODE                                                     |"
    echo "|   RRR Token-Safe Overnight Autopilot                              |"
    echo "|                                                                   |"
    echo "+-------------------------------------------------------------------+"
    echo -e "${NC}"
    echo ""
    echo "Budgets:"
    echo "  MAX_PHASES_PER_RUN=$MAX_PHASES_PER_RUN"
    echo "  MAX_TOTAL_MINUTES=$MAX_TOTAL_MINUTES"
    echo "  MAX_TOTAL_RRR_CALLS=$MAX_TOTAL_RRR_CALLS"
    echo "  MAX_CONSECUTIVE_FAILURES=$MAX_CONSECUTIVE_FAILURES"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# Preflight Checks
# ═══════════════════════════════════════════════════════════════════════════════

check_claude_installed() {
    if ! command -v claude &> /dev/null; then
        log ERROR "Claude Code CLI not found. Install it first: https://claude.ai/code"
        exit 1
    fi
    log OK "Claude Code CLI found"
}

check_mvp_features() {
    if [ -z "$FEATURES_FILE" ] || [ ! -f "$FEATURES_FILE" ]; then
        echo ""
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  ERROR: MVP_FEATURES.yml not found${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Pushpa Mode requires a configured project with feature selections."
        echo ""
        echo "Looked for:"
        echo -e "  ${CYAN}./MVP_FEATURES.yml${NC} (preferred)"
        echo -e "  ${CYAN}./.planning/MVP_FEATURES.yml${NC} (legacy)"
        echo ""
        echo "To get started:"
        echo "  1. Run: /rrr:new-project"
        echo "  2. Complete the questionnaire and capability selection"
        echo "  3. Set required API keys (see below)"
        echo "  4. Run: bash scripts/pushpa-mode.sh"
        echo ""
        exit 1
    fi
    log OK "MVP_FEATURES.yml found at $FEATURES_FILE"
}

check_planning_exists() {
    if [ ! -d "$PLANNING_DIR" ]; then
        log WARN "No .planning directory found"
        return 1
    fi

    local has_state=false
    local has_roadmap=false

    if [ -f "$STATE_FILE" ]; then
        has_state=true
    fi

    if [ -f "$ROADMAP_FILE" ]; then
        has_roadmap=true
    fi

    if [ "$has_state" = true ] || [ "$has_roadmap" = true ]; then
        log OK "Planning directory and initialization files found"
        return 0
    fi

    log WARN "Neither STATE.md nor ROADMAP.md found"
    return 1
}

check_env_vars() {
    local missing_vars=()
    local features_content
    features_content=$(cat "$FEATURES_FILE" 2>/dev/null || echo "")

    log INFO "Checking required environment variables..."

    # Neon (database)
    if echo "$features_content" | grep -q "db:.*neon\|db: neon"; then
        [ -z "${NEON_API_KEY:-}" ] && missing_vars+=("NEON_API_KEY")
        [ -z "${DATABASE_URL:-}" ] && missing_vars+=("DATABASE_URL")
    fi

    # Clerk (auth)
    if echo "$features_content" | grep -q "auth:.*clerk\|auth: clerk"; then
        [ -z "${CLERK_SECRET_KEY:-}" ] && missing_vars+=("CLERK_SECRET_KEY")
        [ -z "${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY:-}" ] && missing_vars+=("NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY")
    fi

    # Stripe (payments)
    if echo "$features_content" | grep -q "payments:.*stripe\|payments: stripe"; then
        [ -z "${STRIPE_SECRET_KEY:-}" ] && missing_vars+=("STRIPE_SECRET_KEY")
    fi

    # Cloudflare R2 (object storage)
    if echo "$features_content" | grep -qE "object_storage:.*cloudflare_r2|object_storage:.*r2|objectStorage:.*cloudflare_r2|objectStorage:.*r2"; then
        [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] && missing_vars+=("CLOUDFLARE_ACCOUNT_ID")
        [ -z "${R2_ACCESS_KEY_ID:-}" ] && missing_vars+=("R2_ACCESS_KEY_ID")
        [ -z "${R2_SECRET_ACCESS_KEY:-}" ] && missing_vars+=("R2_SECRET_ACCESS_KEY")
    fi

    # Deepgram (voice)
    if echo "$features_content" | grep -q "voice:.*deepgram\|voice: deepgram"; then
        [ -z "${DEEPGRAM_API_KEY:-}" ] && missing_vars+=("DEEPGRAM_API_KEY")
    fi

    # PostHog (analytics)
    if echo "$features_content" | grep -q "analytics:.*posthog\|analytics: posthog"; then
        [ -z "${NEXT_PUBLIC_POSTHOG_KEY:-}" ] && missing_vars+=("NEXT_PUBLIC_POSTHOG_KEY")
    fi

    # E2B (sandbox)
    if echo "$features_content" | grep -q "sandbox:.*e2b\|sandbox: e2b"; then
        [ -z "${E2B_API_KEY:-}" ] && missing_vars+=("E2B_API_KEY")
    fi

    # Browserbase
    if echo "$features_content" | grep -q "browser.*browserbase\|browserbase"; then
        [ -z "${BROWSERBASE_API_KEY:-}" ] && missing_vars+=("BROWSERBASE_API_KEY")
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}  WARNING: Missing environment variables${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Based on your MVP_FEATURES.yml, these variables should be set:"
        echo ""
        for var in "${missing_vars[@]}"; do
            echo -e "  ${RED}✗${NC} $var"
        done
        echo ""

        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            STOP_REASON="MISSING_ENV_VARS: User declined to continue"
            return 1
        fi
        log WARN "Continuing with missing environment variables (user override)"
    else
        log OK "All required environment variables are set"
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Phase Discovery
# ═══════════════════════════════════════════════════════════════════════════════

get_phases() {
    if [ ! -f "$ROADMAP_FILE" ]; then
        echo ""
        return
    fi
    grep -oE "Phase [0-9]+(\.[0-9]+)?" "$ROADMAP_FILE" 2>/dev/null | \
        grep -oE "[0-9]+(\.[0-9]+)?" | \
        sort -t. -k1,1n -k2,2n | \
        uniq
}

phase_has_plan() {
    local phase="$1"
    local phase_major="${phase%%.*}"
    local phase_major_padded
    phase_major_padded=$(printf "%02d" "$phase_major")

    local search_pattern
    if [[ "$phase" == *"."* ]]; then
        local phase_full_padded="${phase_major_padded}.${phase#*.}"
        search_pattern="*/${phase_full_padded}-*/*-PLAN.md"
    else
        search_pattern="*/${phase_major_padded}-*/*-PLAN.md"
    fi

    local plan_files
    plan_files=$(find "$PHASES_DIR" -path "$search_pattern" -type f 2>/dev/null | head -1)

    [ -n "$plan_files" ]
}

phase_has_summary() {
    local phase="$1"
    local phase_major="${phase%%.*}"
    local phase_major_padded
    phase_major_padded=$(printf "%02d" "$phase_major")

    local search_pattern
    if [[ "$phase" == *"."* ]]; then
        local phase_full_padded="${phase_major_padded}.${phase#*.}"
        search_pattern="*/${phase_full_padded}-*/*-SUMMARY.md"
    else
        search_pattern="*/${phase_major_padded}-*/*-SUMMARY.md"
    fi

    local summary_files
    summary_files=$(find "$PHASES_DIR" -path "$search_pattern" -type f 2>/dev/null | head -1)

    [ -n "$summary_files" ]
}

get_phase_plans() {
    local phase="$1"
    local phase_major="${phase%%.*}"
    local phase_major_padded
    phase_major_padded=$(printf "%02d" "$phase_major")

    local search_pattern
    if [[ "$phase" == *"."* ]]; then
        local phase_full_padded="${phase_major_padded}.${phase#*.}"
        search_pattern="*/${phase_full_padded}-*/*-PLAN.md"
    else
        search_pattern="*/${phase_major_padded}-*/*-PLAN.md"
    fi

    find "$PHASES_DIR" -path "$search_pattern" -type f 2>/dev/null | sort
}

phase_requires_hitl() {
    local phase="$1"
    local plan_files
    plan_files=$(get_phase_plans "$phase")

    if [ -z "$plan_files" ]; then
        return 1
    fi

    for plan_file in $plan_files; do
        for marker in "${HITL_MARKERS[@]}"; do
            if grep -q "$marker" "$plan_file" 2>/dev/null; then
                log INFO "Found HITL marker '$marker' in $plan_file"
                return 0
            fi
        done
    done

    return 1
}

is_milestone_complete() {
    local completion_markers=("MVP COMPLETE" "MILESTONE COMPLETE" "MISSION_ACCOMPLISHED")

    for marker in "${completion_markers[@]}"; do
        if grep -qi "$marker" "$STATE_FILE" 2>/dev/null; then
            return 0
        fi
        if grep -qi "$marker" "$ROADMAP_FILE" 2>/dev/null; then
            return 0
        fi
    done

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# Execution
# ═══════════════════════════════════════════════════════════════════════════════

run_claude_command() {
    local command="$1"
    local description="$2"

    # Increment RRR calls
    local call_count
    call_count=$(increment_ledger "total_rrr_calls")
    log INFO "RRR call #$call_count: $command"

    # Check budgets before running
    if ! check_budgets; then
        log STOP "$STOP_REASON"
        return 1
    fi

    local output_file="$LOGS_DIR/claude_${RUN_ID}_$(date +%s).log"

    if claude -p "$command" >> "$output_file" 2>&1; then
        log OK "Command completed successfully"
        reset_consecutive_failures
        return 0
    else
        local exit_code=$?
        log ERROR "Command failed (exit $exit_code). Check $output_file"

        # Extract failure signature (first error line)
        local signature
        signature=$(grep -i "error\|failed\|exception" "$output_file" 2>/dev/null | head -1 | cut -c1-100 || echo "unknown_error")
        record_failure "$signature"

        return 1
    fi
}

plan_phase() {
    local phase="$1"

    log INFO "Planning Phase $phase..."

    if ! run_claude_command "/rrr:plan-phase $phase" "Create plan for Phase $phase"; then
        log ERROR "Failed to plan Phase $phase"
        return 1
    fi

    # Verify plan was created
    sleep 2
    if phase_has_plan "$phase"; then
        log OK "Plan created for Phase $phase"
        return 0
    else
        log ERROR "Plan file not found after planning Phase $phase"
        return 1
    fi
}

execute_phase() {
    local phase="$1"

    log INFO "Executing Phase $phase..."

    if ! run_claude_command "/rrr:execute-phase $phase" "Execute Phase $phase"; then
        log ERROR "Failed to execute Phase $phase"
        return 1
    fi

    log OK "Phase $phase execution complete"
    return 0
}

run_visual_proof() {
    log INFO "Running visual proof (Pushpa Mode: headless only)..."

    # ════════════════════════════════════════════════════════════════════
    # VERIFICATION LADDER IN PUSHPA MODE
    # ════════════════════════════════════════════════════════════════════
    # Pushpa Mode runs the verification ladder:
    #
    # | Step               | Pushpa Mode                              |
    # |--------------------|------------------------------------------|
    # | unit_tests         | Yes                                      |
    # | playwright         | Yes                                      |
    # | chrome_visual_check| Only if GUI available AND frontend_impact|
    #
    # Chrome visual check can run non-interactively in some environments.
    # The visual-proof.sh script handles detection and skipping gracefully.
    # ════════════════════════════════════════════════════════════════════

    # Check if visual-proof.sh exists
    if [ -f "scripts/visual-proof.sh" ]; then
        # Determine if phase is frontend-impacting
        # Check last executed plan's frontmatter for frontend_impact
        local frontend_impact="false"
        local last_plan=""
        if [ -d "$PHASES_DIR" ]; then
            last_plan=$(find "$PHASES_DIR" -name "*-PLAN.md" -type f 2>/dev/null | sort -r | head -1)
            if [ -n "$last_plan" ] && [ -f "$last_plan" ]; then
                if grep -q "frontend_impact: true" "$last_plan" 2>/dev/null; then
                    frontend_impact="true"
                fi
            fi
        fi

        log INFO "Running visual proof (frontend_impact=$frontend_impact)..."

        # Run visual proof with pushpa mode flag
        # Pass FRONTEND_IMPACT so the script can decide on chrome step
        FRONTEND_IMPACT="$frontend_impact" bash scripts/visual-proof.sh --pushpa || {
            log WARN "Visual proof failed (non-blocking in Pushpa Mode)"
        }

        # If frontend-impacting and GUI available, also try chrome step
        # The script handles skipping gracefully in CI/no-GUI environments
        if [ "$frontend_impact" = "true" ]; then
            log INFO "Frontend-impacting phase: attempting chrome visual check..."
            FRONTEND_IMPACT="$frontend_impact" bash scripts/visual-proof.sh --pushpa --chrome || {
                log WARN "Chrome visual check skipped or failed (non-blocking)"
            }
        fi
    elif [ -f "$(npm bin)/playwright" ] || command -v npx &>/dev/null; then
        # Fallback: run playwright directly
        if [ -d "e2e" ]; then
            npm run e2e 2>&1 | tee -a "$LOG_FILE" || {
                log WARN "Playwright tests failed (non-blocking)"
            }
        else
            log INFO "No e2e/ directory found, skipping visual proof"
        fi
    else
        log INFO "No Playwright found, skipping visual proof"
    fi
}

backoff_sleep() {
    local attempt="$1"
    local wait_time=$BACKOFF_SECONDS

    if [ "$attempt" -eq 2 ]; then
        wait_time=30
    elif [ "$attempt" -ge 3 ]; then
        wait_time=60
    fi

    log INFO "Backoff: waiting ${wait_time}s before retry..."
    sleep "$wait_time"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Report Generation
# ═══════════════════════════════════════════════════════════════════════════════

declare -a PLANNED_PHASES=()
declare -a EXECUTED_PHASES=()
declare -a SKIPPED_PHASES=()
declare -a FAILED_PHASES=()

generate_report() {
    local end_time
    end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local elapsed
    elapsed=$(update_elapsed_time)
    local rrr_calls
    rrr_calls=$(read_ledger_int "total_rrr_calls")

    cat > "$REPORT_FILE" << EOF
# Pushpa Mode Report

**Run ID:** $RUN_ID
**Started:** $(date -d "@$START_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$START_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
**Completed:** $end_time
**Duration:** ${elapsed} minutes
**Stop Reason:** ${STOP_REASON:-"Completed normally"}

---

## Budget Usage

| Budget | Used | Limit | Status |
|--------|------|-------|--------|
| RRR Calls | $rrr_calls | $MAX_TOTAL_RRR_CALLS | $([ "$rrr_calls" -lt "$MAX_TOTAL_RRR_CALLS" ] && echo "OK" || echo "EXCEEDED") |
| Minutes | $elapsed | $MAX_TOTAL_MINUTES | $([ "$elapsed" -lt "$MAX_TOTAL_MINUTES" ] && echo "OK" || echo "EXCEEDED") |
| Phases | ${#EXECUTED_PHASES[@]} | $MAX_PHASES_PER_RUN | $([ "${#EXECUTED_PHASES[@]}" -lt "$MAX_PHASES_PER_RUN" ] && echo "OK" || echo "LIMIT") |

---

## Summary

| Metric | Count |
|--------|-------|
| Phases Planned | ${#PLANNED_PHASES[@]} |
| Phases Executed | ${#EXECUTED_PHASES[@]} |
| Phases Skipped (HITL) | ${#SKIPPED_PHASES[@]} |
| Phases Failed | ${#FAILED_PHASES[@]} |

---

## Phase Details

EOF

    if [ ${#EXECUTED_PHASES[@]} -gt 0 ]; then
        echo "### Executed" >> "$REPORT_FILE"
        for phase in "${EXECUTED_PHASES[@]}"; do
            echo "- Phase $phase ✓" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
    fi

    if [ ${#SKIPPED_PHASES[@]} -gt 0 ]; then
        echo "### Skipped (HITL Required)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        echo "These phases require human verification and were skipped:" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        for phase in "${SKIPPED_PHASES[@]}"; do
            echo "- Phase $phase — **HITL_REQUIRED**" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
        echo "> Run these phases manually with \`/rrr:execute-phase N\` after verification." >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi

    if [ ${#FAILED_PHASES[@]} -gt 0 ]; then
        echo "### Failed" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        for phase in "${FAILED_PHASES[@]}"; do
            echo "- Phase $phase ✗" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF
---

## Artifacts

| Artifact | Path |
|----------|------|
| Ledger | \`$LEDGER_FILE\` |
| Log | \`$LOG_FILE\` |
| Visual Proof | \`$VISUAL_PROOF_FILE\` |
| Playwright Report | \`$ARTIFACTS_DIR/playwright/report\` |

---

*Generated by Pushpa Mode*
EOF

    log OK "Report saved to $REPORT_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # Run Claude Code check first (before banner)
    check_claude_code_environment

    print_banner

    # Initialize ledger and logging
    init_ledger

    log INFO "Pushpa Mode starting..."
    log INFO "Working directory: $(pwd)"

    # Preflight checks
    echo -e "${BOLD}Preflight Checks${NC}"
    echo "─────────────────────────────────────────"

    check_claude_installed
    check_mvp_features

    if ! check_env_vars; then
        generate_report
        exit 1
    fi

    if ! check_planning_exists; then
        log WARN "Project not initialized."
        echo ""
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}  Project not initialized. Run /rrr:new-project first.${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
        echo ""
        STOP_REASON="NOT_INITIALIZED: Project not initialized"
        generate_report
        exit 1
    fi

    # Check git conflicts
    if ! check_git_conflicts; then
        log STOP "$STOP_REASON"
        generate_report
        exit 1
    fi

    echo ""
    echo -e "${GREEN}All preflight checks passed!${NC}"
    echo ""

    # Check if already complete
    if is_milestone_complete; then
        log OK "Milestone is already complete!"
        STOP_REASON="MILESTONE_COMPLETE: Already complete"
        generate_report
        exit 0
    fi

    # Get phases
    local phases
    phases=$(get_phases)

    if [ -z "$phases" ]; then
        log ERROR "No phases found in ROADMAP.md"
        STOP_REASON="NO_PHASES: No phases found in ROADMAP.md"
        generate_report
        exit 1
    fi

    log INFO "Found phases: $(echo $phases | tr '\n' ' ')"

    echo -e "${BOLD}Starting Execution${NC}"
    echo "─────────────────────────────────────────"
    echo ""

    # Process each phase (filesystem-driven, no polling)
    for phase in $phases; do
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  Phase $phase${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Check budgets before each phase
        if ! check_budgets; then
            log STOP "$STOP_REASON"
            break
        fi

        # Check git conflicts
        if ! check_git_conflicts; then
            log STOP "$STOP_REASON"
            break
        fi

        # Filesystem-driven decision:
        # 1. If no plan exists -> run plan-phase
        # 2. If plan exists but no summary -> run execute-phase
        # 3. If summary exists -> skip (already done)

        if phase_has_summary "$phase"; then
            log OK "Phase $phase already has SUMMARY, skipping"
            continue
        fi

        # Check for HITL marker in existing plans
        if phase_has_plan "$phase" && phase_requires_hitl "$phase"; then
            log SKIP "Phase $phase requires human verification (HITL_REQUIRED)"
            echo -e "${YELLOW}  Skipping - Human verification required${NC}"
            SKIPPED_PHASES+=("$phase")
            continue
        fi

        # Plan if needed
        if ! phase_has_plan "$phase"; then
            log INFO "No plan found for Phase $phase, creating..."

            local plan_attempt=0
            local plan_success=false

            while [ $plan_attempt -lt "$MAX_PLAN_ATTEMPTS_PER_PHASE" ]; do
                ((plan_attempt++))

                if plan_phase "$phase"; then
                    PLANNED_PHASES+=("$phase")
                    plan_success=true
                    break
                else
                    log WARN "Plan attempt $plan_attempt failed for Phase $phase"
                    if [ $plan_attempt -lt "$MAX_PLAN_ATTEMPTS_PER_PHASE" ]; then
                        backoff_sleep "$plan_attempt"
                    fi
                fi
            done

            if [ "$plan_success" = false ]; then
                log ERROR "Failed to create plan for Phase $phase after $plan_attempt attempts"
                FAILED_PHASES+=("$phase")
                continue
            fi

            # Re-check for HITL after planning
            if phase_requires_hitl "$phase"; then
                log SKIP "Phase $phase marked HITL after planning"
                SKIPPED_PHASES+=("$phase")
                continue
            fi
        else
            log OK "Plan already exists for Phase $phase"
        fi

        # Execute phase
        local exec_attempt=0
        local exec_success=false

        while [ $exec_attempt -lt "$MAX_EXEC_ATTEMPTS_PER_PHASE" ]; do
            ((exec_attempt++))

            if execute_phase "$phase"; then
                EXECUTED_PHASES+=("$phase")
                increment_ledger "phases_completed"
                exec_success=true
                echo -e "${GREEN}  ✓ Phase $phase complete${NC}"
                break
            else
                log WARN "Execution attempt $exec_attempt failed for Phase $phase"
                if [ $exec_attempt -lt "$MAX_EXEC_ATTEMPTS_PER_PHASE" ]; then
                    backoff_sleep "$exec_attempt"
                fi
            fi

            # Check budgets after each attempt
            if ! check_budgets; then
                log STOP "$STOP_REASON"
                break 2
            fi
        done

        if [ "$exec_success" = false ]; then
            log ERROR "Failed to execute Phase $phase after $exec_attempt attempts"
            FAILED_PHASES+=("$phase")
            echo -e "${RED}  ✗ Phase $phase failed${NC}"
        fi

        # Run visual proof after each completed phase
        if [ "$exec_success" = true ]; then
            run_visual_proof
        fi

        # Check if milestone became complete
        if is_milestone_complete; then
            log OK "Milestone complete!"
            STOP_REASON="MILESTONE_COMPLETE: All phases done"
            break
        fi
    done

    # Generate final report
    if [ -z "$STOP_REASON" ]; then
        STOP_REASON="COMPLETED: All scheduled phases processed"
    fi
    generate_report

    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Pushpa Mode Complete${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Results:"
    echo "  Planned:  ${#PLANNED_PHASES[@]} phases"
    echo "  Executed: ${#EXECUTED_PHASES[@]} phases"
    echo "  Skipped:  ${#SKIPPED_PHASES[@]} phases (HITL required)"
    echo "  Failed:   ${#FAILED_PHASES[@]} phases"
    echo ""
    echo "Stop Reason: $STOP_REASON"
    echo ""
    echo "Report: $REPORT_FILE"
    echo "Ledger: $LEDGER_FILE"
    echo "Logs:   $LOG_FILE"
    echo ""

    if [ ${#SKIPPED_PHASES[@]} -gt 0 ]; then
        echo -e "${YELLOW}HITL phases to complete manually:${NC}"
        for phase in "${SKIPPED_PHASES[@]}"; do
            echo "  /rrr:execute-phase $phase"
        done
        echo ""
    fi

    if [ ${#FAILED_PHASES[@]} -gt 0 ]; then
        echo -e "${RED}Failed phases to investigate:${NC}"
        for phase in "${FAILED_PHASES[@]}"; do
            echo "  Phase $phase"
        done
        echo ""
        exit 1
    fi

    log OK "Pushpa Mode finished"
}

# Run main
main "$@"
