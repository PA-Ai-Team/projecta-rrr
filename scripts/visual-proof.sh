#!/bin/bash
#
# Visual Proof Runner for RRR
# Runs Playwright tests and captures UX telemetry, appending results to VISUAL_PROOF.md
#
# Usage: bash scripts/visual-proof.sh [--headed] [--interactive]
#
# Modes (from .planning/config.json visual_proof.mode):
# - playwright: headless Playwright + artifacts (default)
# - playwright_headed: headed if TTY, else headless
# - hybrid: headless first; prompt for interactive fallback on eligible failures
# - interactive_only: skip Playwright; print interactive UAT checklist
#
# Options:
# --headed: Force headed mode
# --interactive: Skip Playwright, run interactive guidance
# --pushpa: Running in Pushpa Mode (never interactive)
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

PLANNING_DIR=".planning"
CONFIG_FILE="$PLANNING_DIR/config.json"
VISUAL_PROOF_FILE="$PLANNING_DIR/VISUAL_PROOF.md"
ARTIFACTS_DIR="$PLANNING_DIR/artifacts"
PLAYWRIGHT_REPORT="$ARTIFACTS_DIR/playwright/report"
PLAYWRIGHT_RESULTS="$ARTIFACTS_DIR/playwright/test-results"
UX_TELEMETRY_DIR="$ARTIFACTS_DIR/ux-telemetry"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
HEADED=false
INTERACTIVE=false
PUSHPA_MODE=false
RUN_ID=$(date +%Y%m%d_%H%M%S)

# ═══════════════════════════════════════════════════════════════════════════════
# Parse Arguments
# ═══════════════════════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
    case $1 in
        --headed)
            HEADED=true
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --pushpa)
            PUSHPA_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

log() {
    local level="$1"
    local message="$2"
    case "$level" in
        INFO)  echo -e "${CYAN}[VISUAL]${NC} $message" ;;
        OK)    echo -e "${GREEN}[VISUAL]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[VISUAL]${NC} $message" ;;
        ERROR) echo -e "${RED}[VISUAL]${NC} $message" ;;
        *)     echo "[VISUAL] $message" ;;
    esac
}

is_tty() {
    [ -t 1 ]
}

read_config_value() {
    local key="$1"
    local default="$2"
    if [ -f "$CONFIG_FILE" ]; then
        local value
        value=$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "")
        if [ -n "$value" ]; then
            echo "$value"
            return
        fi
        # Try boolean
        value=$(grep -o "\"$key\"[[:space:]]*:[[:space:]]*\(true\|false\)" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*: *\(true\|false\).*/\1/' || echo "")
        if [ -n "$value" ]; then
            echo "$value"
            return
        fi
    fi
    echo "$default"
}

get_visual_proof_mode() {
    read_config_value "mode" "playwright"
}

get_fallback_to_interactive() {
    read_config_value "fallback_to_interactive" "false"
}

playwright_tests_exist() {
    # Check if e2e/ directory exists and has test files
    if [ -d "e2e" ]; then
        local count
        count=$(find e2e -name "*.spec.ts" -o -name "*.test.ts" 2>/dev/null | wc -l | tr -d ' ')
        [ "$count" -gt 0 ]
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Functions
# ═══════════════════════════════════════════════════════════════════════════════

run_playwright() {
    local headed_flag=""

    if [ "$HEADED" = true ]; then
        headed_flag="--headed"
    fi

    log INFO "Running Playwright tests..."

    # Ensure artifacts directories exist
    mkdir -p "$PLAYWRIGHT_REPORT" "$PLAYWRIGHT_RESULTS" "$UX_TELEMETRY_DIR"

    # Run Playwright
    local exit_code=0
    npm run e2e -- $headed_flag 2>&1 | tee "$ARTIFACTS_DIR/playwright-output-$RUN_ID.log" || exit_code=$?

    return $exit_code
}

count_telemetry() {
    local console_errors=0
    local page_errors=0
    local network_failures=0

    # Find the most recent telemetry summary
    if [ -d "$UX_TELEMETRY_DIR" ]; then
        local latest_summary
        latest_summary=$(find "$UX_TELEMETRY_DIR" -name "summary.json" -type f 2>/dev/null | sort -r | head -1)
        if [ -n "$latest_summary" ] && [ -f "$latest_summary" ]; then
            console_errors=$(grep -o '"consoleErrors"[[:space:]]*:[[:space:]]*[0-9]*' "$latest_summary" 2>/dev/null | grep -o '[0-9]*$' || echo "0")
            page_errors=$(grep -o '"pageErrors"[[:space:]]*:[[:space:]]*[0-9]*' "$latest_summary" 2>/dev/null | grep -o '[0-9]*$' || echo "0")
            network_failures=$(grep -o '"networkFailures"[[:space:]]*:[[:space:]]*[0-9]*' "$latest_summary" 2>/dev/null | grep -o '[0-9]*$' || echo "0")
        fi
    fi

    echo "$console_errors $page_errors $network_failures"
}

append_visual_proof() {
    local status="$1"
    local exit_code="$2"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local telemetry_counts
    telemetry_counts=$(count_telemetry)
    local console_errors=$(echo "$telemetry_counts" | cut -d' ' -f1)
    local page_errors=$(echo "$telemetry_counts" | cut -d' ' -f2)
    local network_failures=$(echo "$telemetry_counts" | cut -d' ' -f3)

    # Create file if it doesn't exist
    if [ ! -f "$VISUAL_PROOF_FILE" ]; then
        cat > "$VISUAL_PROOF_FILE" << 'EOF'
# Visual Proof Log

Append-only log of visual proof runs.

---

EOF
    fi

    # Append entry
    cat >> "$VISUAL_PROOF_FILE" << EOF

## Run: $RUN_ID

- **Timestamp:** $timestamp
- **Status:** $status
- **Exit Code:** $exit_code

### Artifacts
- Report: \`$PLAYWRIGHT_REPORT\`
- Test Results: \`$PLAYWRIGHT_RESULTS\`
EOF

    # Add telemetry if any issues found
    if [ "$console_errors" -gt 0 ] || [ "$page_errors" -gt 0 ] || [ "$network_failures" -gt 0 ]; then
        cat >> "$VISUAL_PROOF_FILE" << EOF

### UX Telemetry
| Metric | Count |
|--------|-------|
| Console Errors | $console_errors |
| Page Errors | $page_errors |
| Network Failures | $network_failures |
EOF
    fi

    echo "" >> "$VISUAL_PROOF_FILE"
    echo "---" >> "$VISUAL_PROOF_FILE"
}

run_interactive_uat() {
    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  INTERACTIVE VISUAL PROOF${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Options for manual verification:"
    echo ""
    echo "  1. Run headed Playwright:"
    echo -e "     ${CYAN}npm run e2e:headed${NC}"
    echo ""
    echo "  2. Use Playwright UI mode:"
    echo -e "     ${CYAN}npm run e2e:ui${NC}"
    echo ""
    echo "  3. Open last report:"
    echo -e "     ${CYAN}npm run visual:open${NC}"
    echo ""
    echo "After verification, record results manually or re-run visual proof."
    echo ""
}

prompt_interactive_fallback() {
    if [ "$PUSHPA_MODE" = true ]; then
        log WARN "Pushpa Mode: skipping interactive fallback"
        return 1
    fi

    if ! is_tty; then
        log WARN "No TTY: skipping interactive fallback"
        return 1
    fi

    echo ""
    read -r -p "Playwright failed. Run Interactive UI check now? (y/N): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    fi
    return 1
}

is_eligible_for_interactive() {
    local exit_code="$1"

    # Check if this is an app/UX failure vs env/build failure
    # Look at the playwright output log for clues
    local log_file="$ARTIFACTS_DIR/playwright-output-$RUN_ID.log"

    if [ -f "$log_file" ]; then
        # These patterns indicate env/build issues, NOT eligible for interactive
        if grep -qE "Cannot find module|ENOENT|npm ERR|build failed|Missing.*dependency" "$log_file" 2>/dev/null; then
            return 1
        fi
    fi

    # Non-zero exit from tests is eligible
    [ "$exit_code" -ne 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN} RRR ► VISUAL PROOF${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check if Playwright tests exist
    if ! playwright_tests_exist; then
        log WARN "No Playwright tests found in e2e/ directory"
        log INFO "Skipping visual proof (no tests to run)"
        exit 0
    fi

    # Get mode from config
    local mode
    mode=$(get_visual_proof_mode)
    local fallback
    fallback=$(get_fallback_to_interactive)

    # Override mode based on flags
    if [ "$INTERACTIVE" = true ]; then
        mode="interactive_only"
    fi

    # Pushpa Mode forces headless, never interactive
    if [ "$PUSHPA_MODE" = true ]; then
        if [ "$mode" = "hybrid" ] || [ "$mode" = "interactive_only" ]; then
            log WARN "Pushpa Mode: overriding $mode to playwright (headless)"
            mode="playwright"
        fi
        HEADED=false
    fi

    log INFO "Mode: $mode"

    case "$mode" in
        interactive_only)
            run_interactive_uat
            exit 0
            ;;

        playwright_headed)
            if is_tty; then
                HEADED=true
            fi
            ;;

        hybrid)
            # Will run headless first, then offer fallback
            ;;

        playwright|*)
            # Default headless
            ;;
    esac

    # Ensure artifacts directory exists
    mkdir -p "$ARTIFACTS_DIR"

    # Run Playwright
    local exit_code=0
    run_playwright || exit_code=$?

    # Determine status
    local status
    if [ $exit_code -eq 0 ]; then
        status="PASSED"
        log OK "Visual proof passed"
    else
        status="FAILED"
        log ERROR "Visual proof failed (exit code: $exit_code)"
    fi

    # Append to VISUAL_PROOF.md
    append_visual_proof "$status" "$exit_code"
    log INFO "Results appended to $VISUAL_PROOF_FILE"

    # Handle hybrid mode fallback
    if [ "$mode" = "hybrid" ] && [ "$exit_code" -ne 0 ]; then
        if [ "$fallback" = "true" ]; then
            if is_eligible_for_interactive "$exit_code"; then
                if prompt_interactive_fallback; then
                    run_interactive_uat
                fi
            else
                log WARN "Failure appears to be env/build issue, not eligible for interactive fallback"
            fi
        fi
    fi

    # Print report location
    echo ""
    echo -e "${BOLD}Artifacts:${NC}"
    echo "  Report:  $PLAYWRIGHT_REPORT"
    echo "  Results: $PLAYWRIGHT_RESULTS"
    echo "  Log:     $VISUAL_PROOF_FILE"
    echo ""
    echo -e "Open report: ${CYAN}npm run visual:open${NC}"
    echo ""

    exit $exit_code
}

main "$@"
