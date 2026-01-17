#!/bin/bash
#
# Pushpa Mode - Unattended Overnight Runner for RRR
# Runs plan+execute phases sequentially, skipping HITL-marked phases
#
# Usage: bash scripts/pushpa-mode.sh
#
# Requirements:
# - MVP_FEATURES.yml must exist (.planning/MVP_FEATURES.yml)
# - Required API keys must be set based on your feature selections
# - Claude Code must be installed and configured
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

PLANNING_DIR=".planning"
PHASES_DIR="$PLANNING_DIR/phases"
LOGS_DIR="$PLANNING_DIR/logs"
FEATURES_FILE="$PLANNING_DIR/MVP_FEATURES.yml"
STATE_FILE="$PLANNING_DIR/STATE.md"
ROADMAP_FILE="$PLANNING_DIR/ROADMAP.md"
REPORT_FILE="$PLANNING_DIR/PUSHPA_REPORT.md"

# HITL markers that indicate human verification required
HITL_MARKERS=("HITL_REQUIRED: true" "HUMAN_VERIFICATION_REQUIRED" "MANUAL_VERIFICATION")

# Polling configuration
POLL_INTERVAL=10  # seconds between checks
MAX_POLL_ATTEMPTS=360  # 1 hour max wait (360 * 10s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# Logging
# ═══════════════════════════════════════════════════════════════════════════════

LOG_FILE=""
START_TIME=""

setup_logging() {
    mkdir -p "$LOGS_DIR"
    START_TIME=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="$LOGS_DIR/pushpa_${START_TIME}.log"
    touch "$LOG_FILE"
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        INFO)  echo -e "${CYAN}[$level]${NC} $message" ;;
        OK)    echo -e "${GREEN}[$level]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[$level]${NC} $message" ;;
        ERROR) echo -e "${RED}[$level]${NC} $message" ;;
        SKIP)  echo -e "${YELLOW}[SKIP]${NC} $message" ;;
        *)     echo "[$level] $message" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# Banner
# ═══════════════════════════════════════════════════════════════════════════════

print_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   ██████╗ ██╗   ██╗███████╗██╗  ██╗██████╗  █████╗            ║"
    echo "║   ██╔══██╗██║   ██║██╔════╝██║  ██║██╔══██╗██╔══██╗           ║"
    echo "║   ██████╔╝██║   ██║███████╗███████║██████╔╝███████║           ║"
    echo "║   ██╔═══╝ ██║   ██║╚════██║██╔══██║██╔═══╝ ██╔══██║           ║"
    echo "║   ██║     ╚██████╔╝███████║██║  ██║██║     ██║  ██║           ║"
    echo "║   ╚═╝      ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝           ║"
    echo "║                                                               ║"
    echo "║              RRR Overnight Autopilot Runner                   ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
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
    if [ ! -f "$FEATURES_FILE" ]; then
        echo ""
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  ERROR: MVP_FEATURES.yml not found${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Pushpa Mode requires a configured project with feature selections."
        echo ""
        echo "To get started:"
        echo "  1. Run: /rrr:new-project"
        echo "  2. Complete the questionnaire and capability selection"
        echo "  3. Set required API keys (see below)"
        echo "  4. Run: bash scripts/pushpa-mode.sh"
        echo ""
        exit 1
    fi
    log OK "MVP_FEATURES.yml found"
}

check_planning_exists() {
    if [ ! -d "$PLANNING_DIR" ]; then
        log WARN "No .planning directory found"
        return 1
    fi

    if [ ! -f "$ROADMAP_FILE" ]; then
        log WARN "No ROADMAP.md found"
        return 1
    fi

    log OK "Planning directory and roadmap found"
    return 0
}

# Check required environment variables based on MVP_FEATURES.yml
check_env_vars() {
    local missing_vars=()
    local features_content=$(cat "$FEATURES_FILE" 2>/dev/null || echo "")

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
        [ -z "${NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY:-}" ] && missing_vars+=("NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY (optional)")
    fi

    # Cloudflare R2 (storage)
    if echo "$features_content" | grep -q "object_storage:.*r2\|objectStorage:.*r2"; then
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
        [ -z "${NEXT_PUBLIC_POSTHOG_HOST:-}" ] && missing_vars+=("NEXT_PUBLIC_POSTHOG_HOST")
    fi

    # E2B (sandbox)
    if echo "$features_content" | grep -q "sandbox:.*e2b\|sandbox: e2b"; then
        [ -z "${E2B_API_KEY:-}" ] && missing_vars+=("E2B_API_KEY")
    fi

    # Browserbase
    if echo "$features_content" | grep -q "browser.*browserbase\|browserbase"; then
        [ -z "${BROWSERBASE_API_KEY:-}" ] && missing_vars+=("BROWSERBASE_API_KEY")
        [ -z "${BROWSERBASE_PROJECT_ID:-}" ] && missing_vars+=("BROWSERBASE_PROJECT_ID")
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
        echo "Set them in your environment or .env file before running Pushpa Mode."
        echo ""
        echo "Example:"
        echo "  export NEON_API_KEY=your_key_here"
        echo "  # or"
        echo "  source .env"
        echo ""

        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log ERROR "Aborted due to missing environment variables"
            exit 1
        fi
        log WARN "Continuing with missing environment variables (user override)"
    else
        log OK "All required environment variables are set"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Phase Discovery
# ═══════════════════════════════════════════════════════════════════════════════

# Get list of phases from ROADMAP.md
get_phases() {
    if [ ! -f "$ROADMAP_FILE" ]; then
        echo ""
        return
    fi

    # Extract phase numbers from ROADMAP.md
    # Looks for patterns like "## Phase 1:" or "### Phase 1:" or "| 1 |"
    grep -oE "Phase [0-9]+(\.[0-9]+)?" "$ROADMAP_FILE" 2>/dev/null | \
        grep -oE "[0-9]+(\.[0-9]+)?" | \
        sort -t. -k1,1n -k2,2n | \
        uniq
}

# Check if phase has a plan
phase_has_plan() {
    local phase="$1"
    local phase_padded=$(printf "%02d" "${phase%%.*}")

    # Look for plan files in the phase directory
    local plan_files=$(find "$PHASES_DIR" -path "*/${phase_padded}*/*-PLAN.md" -type f 2>/dev/null | head -1)

    if [ -n "$plan_files" ]; then
        return 0
    fi
    return 1
}

# Get plan files for a phase
get_phase_plans() {
    local phase="$1"
    local phase_padded=$(printf "%02d" "${phase%%.*}")

    find "$PHASES_DIR" -path "*/${phase_padded}*/*-PLAN.md" -type f 2>/dev/null | sort
}

# Check if phase plan contains HITL marker
phase_requires_hitl() {
    local phase="$1"
    local plan_files=$(get_phase_plans "$phase")

    if [ -z "$plan_files" ]; then
        return 1  # No plan, no HITL
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

# Check if milestone is complete
is_milestone_complete() {
    local completion_markers=("MVP COMPLETE" "MILESTONE COMPLETE" "ALL PHASES COMPLETE" "100%")

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

# Run a Claude Code command
run_claude_command() {
    local command="$1"
    local description="$2"

    log INFO "Running: $command"
    log INFO "Description: $description"

    # Run claude with the command, capturing output
    local output_file="$LOGS_DIR/claude_${START_TIME}_$(date +%s).log"

    if claude -p "$command" >> "$output_file" 2>&1; then
        log OK "Command completed successfully"
        return 0
    else
        log ERROR "Command failed. Check $output_file for details"
        return 1
    fi
}

# Wait for plan files to appear
wait_for_plan() {
    local phase="$1"
    local attempts=0

    log INFO "Waiting for plan files for Phase $phase..."

    while [ $attempts -lt $MAX_POLL_ATTEMPTS ]; do
        if phase_has_plan "$phase"; then
            log OK "Plan files found for Phase $phase"
            return 0
        fi

        sleep $POLL_INTERVAL
        ((attempts++))

        if [ $((attempts % 6)) -eq 0 ]; then
            log INFO "Still waiting for plan files... (${attempts}/${MAX_POLL_ATTEMPTS})"
        fi
    done

    log ERROR "Timeout waiting for plan files for Phase $phase"
    return 1
}

# Plan a phase
plan_phase() {
    local phase="$1"

    log INFO "Planning Phase $phase..."

    if ! run_claude_command "/rrr:plan-phase $phase" "Create plan for Phase $phase"; then
        log ERROR "Failed to plan Phase $phase"
        return 1
    fi

    # Wait for plan files to appear
    if ! wait_for_plan "$phase"; then
        return 1
    fi

    return 0
}

# Execute a phase
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

# ═══════════════════════════════════════════════════════════════════════════════
# Report Generation
# ═══════════════════════════════════════════════════════════════════════════════

# Phase tracking arrays
declare -a PLANNED_PHASES=()
declare -a EXECUTED_PHASES=()
declare -a SKIPPED_PHASES=()
declare -a FAILED_PHASES=()

init_report() {
    cat > "$REPORT_FILE" << EOF
# Pushpa Mode Report

**Started:** $(date '+%Y-%m-%d %H:%M:%S')
**Log File:** $LOG_FILE

---

## Summary

| Metric | Count |
|--------|-------|
| Phases Planned | — |
| Phases Executed | — |
| Phases Skipped (HITL) | — |
| Phases Failed | — |

---

## Phase Details

EOF
}

update_report() {
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$REPORT_FILE" << EOF
# Pushpa Mode Report

**Started:** $(date -d "@$(($(date +%s) - SECONDS))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$(date '+%Y-%m-%d %H:%M:%S')")
**Completed:** $end_time
**Duration:** $((SECONDS / 60)) minutes
**Log File:** $LOG_FILE

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
        echo "These phases encountered errors:" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        for phase in "${FAILED_PHASES[@]}"; do
            echo "- Phase $phase ✗" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
        echo "> Check logs at \`$LOGS_DIR/\` for details." >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi

    echo "---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "*Generated by Pushpa Mode*" >> "$REPORT_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    print_banner
    setup_logging

    log INFO "Pushpa Mode starting..."
    log INFO "Working directory: $(pwd)"

    # Preflight checks
    echo -e "${BOLD}Preflight Checks${NC}"
    echo "─────────────────────────────────────────"

    check_claude_installed
    check_mvp_features
    check_env_vars

    # Check if planning exists, run new-project if not
    if ! check_planning_exists; then
        log WARN "Planning not initialized. Running /rrr:new-project..."
        echo ""
        echo -e "${YELLOW}Planning not found. Please run /rrr:new-project first.${NC}"
        echo ""
        echo "Pushpa Mode requires:"
        echo "  1. .planning/ROADMAP.md (phases defined)"
        echo "  2. .planning/MVP_FEATURES.yml (feature selections)"
        echo ""
        echo "Run /rrr:new-project interactively to set up your project,"
        echo "then run Pushpa Mode again."
        exit 1
    fi

    echo ""
    echo -e "${GREEN}All preflight checks passed!${NC}"
    echo ""

    # Check if already complete
    if is_milestone_complete; then
        log OK "Milestone is already complete!"
        echo -e "${GREEN}Milestone is already complete. Nothing to do.${NC}"
        exit 0
    fi

    # Get phases
    local phases=$(get_phases)

    if [ -z "$phases" ]; then
        log ERROR "No phases found in ROADMAP.md"
        exit 1
    fi

    log INFO "Found phases: $(echo $phases | tr '\n' ' ')"

    # Initialize report
    init_report

    echo -e "${BOLD}Starting Execution${NC}"
    echo "─────────────────────────────────────────"
    echo ""

    # Process each phase
    for phase in $phases; do
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  Phase $phase${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Check if plan exists
        if ! phase_has_plan "$phase"; then
            log INFO "No plan found for Phase $phase, creating..."

            if plan_phase "$phase"; then
                PLANNED_PHASES+=("$phase")
            else
                log ERROR "Failed to create plan for Phase $phase"
                FAILED_PHASES+=("$phase")
                continue
            fi
        else
            log OK "Plan already exists for Phase $phase"
        fi

        # Check for HITL marker
        if phase_requires_hitl "$phase"; then
            log SKIP "Phase $phase requires human verification (HITL_REQUIRED)"
            echo -e "${YELLOW}  ⚠ Skipping - Human verification required${NC}"
            SKIPPED_PHASES+=("$phase")
            continue
        fi

        # Execute phase
        if execute_phase "$phase"; then
            EXECUTED_PHASES+=("$phase")
            echo -e "${GREEN}  ✓ Phase $phase complete${NC}"
        else
            FAILED_PHASES+=("$phase")
            echo -e "${RED}  ✗ Phase $phase failed${NC}"
        fi

        # Check if milestone became complete
        if is_milestone_complete; then
            log OK "Milestone complete!"
            break
        fi
    done

    # Generate final report
    update_report

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
    echo "Report: $REPORT_FILE"
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

    log OK "Pushpa Mode finished successfully"
}

# Run main
main "$@"
