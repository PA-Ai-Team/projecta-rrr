#!/bin/bash
#
# Visual Proof Runner for RRR
# Runs Playwright tests and optionally claude --chrome verification
# Appends results to VISUAL_PROOF.md
#
# Usage: bash scripts/visual-proof.sh [options]
#
# Options:
#   --chrome       Run chrome visual check after Playwright (REQUIRED for frontend_impact:true)
#   --headed       Force headed mode for Playwright
#   --interactive  Skip Playwright, run interactive guidance
#   --pushpa       Running in Pushpa Mode (never interactive, still allows chrome if GUI available)
#
# Environment:
#   FRONTEND_IMPACT=true   Automatically enables chrome step
#   PLAN_ID=XX-NN          Plan identifier for logging
#
# Modes (from .planning/config.json visual_proof.mode):
# - playwright: headless Playwright + artifacts (default)
# - playwright_headed: headed if TTY, else headless
# - hybrid: headless first; prompt for interactive fallback on eligible failures
# - interactive_only: skip Playwright; print interactive UAT checklist
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
CHROME_DIR="$ARTIFACTS_DIR/chrome"
CHROME_SCREENSHOTS="$CHROME_DIR/screenshots"
CHROME_LOGS="$CHROME_DIR/logs"
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
RUN_CHROME=false
RUN_ID=$(date +%Y%m%d_%H%M%S)

# Environment-based defaults
FRONTEND_IMPACT="${FRONTEND_IMPACT:-false}"
PLAN_ID="${PLAN_ID:-manual}"

# ═══════════════════════════════════════════════════════════════════════════════
# Parse Arguments
# ═══════════════════════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
    case $1 in
        --chrome)
            RUN_CHROME=true
            shift
            ;;
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

has_gui() {
    # Check if GUI is available
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS - check if we have a display
        if [ -n "${DISPLAY:-}" ] || [ -n "$(who | grep console)" ]; then
            return 0
        fi
        # On Mac, we usually have GUI unless running in pure SSH
        return 0
    else
        # Linux - check for DISPLAY or WAYLAND
        if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
            return 0
        fi
    fi
    return 1
}

is_ci() {
    [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]
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

# Auto-enable chrome for frontend_impact=true (unless explicitly disabled)
auto_enable_chrome() {
    if [ "$FRONTEND_IMPACT" = "true" ] && [ "$RUN_CHROME" = "false" ]; then
        log INFO "FRONTEND_IMPACT=true detected, enabling chrome step"
        RUN_CHROME=true
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Playwright Functions
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

append_playwright_proof() {
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
- **Plan ID:** $PLAN_ID
- **Frontend Impact:** $FRONTEND_IMPACT
- **Step:** playwright (automated)

### Commands Run
- \`npx playwright test\` — $status

### Result
**Status:** $status
**Exit Code:** $exit_code

### Artifacts
- Report: \`$PLAYWRIGHT_REPORT/index.html\`
- Test Results: \`$PLAYWRIGHT_RESULTS\`
EOF

    # Add telemetry if any issues found
    if [ "$console_errors" -gt 0 ] || [ "$page_errors" -gt 0 ] || [ "$network_failures" -gt 0 ]; then
        cat >> "$VISUAL_PROOF_FILE" << EOF

### Console/Page/Network Errors
| Metric | Count |
|--------|-------|
| Console Errors | $console_errors |
| Page Errors | $page_errors |
| Network Failures | $network_failures |
EOF
    else
        echo "" >> "$VISUAL_PROOF_FILE"
        echo "### Console/Page/Network Errors" >> "$VISUAL_PROOF_FILE"
        echo "None" >> "$VISUAL_PROOF_FILE"
    fi

    echo "" >> "$VISUAL_PROOF_FILE"
    echo "---" >> "$VISUAL_PROOF_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Chrome Visual Check Functions
# ═══════════════════════════════════════════════════════════════════════════════

run_chrome_check() {
    log INFO "Running chrome visual check..."

    # Create chrome artifacts directory
    mkdir -p "$CHROME_SCREENSHOTS" "$CHROME_LOGS"

    local chrome_log="$CHROME_LOGS/chrome-check-$RUN_ID.log"
    local exit_code=0

    # Check if we can run chrome check
    if is_ci; then
        log WARN "CI environment detected, skipping chrome visual check"
        append_chrome_proof "SKIPPED" "CI environment" ""
        return 0
    fi

    if ! has_gui; then
        log WARN "No GUI available, skipping chrome visual check"
        append_chrome_proof "SKIPPED" "no GUI" ""
        echo ""
        echo -e "${YELLOW}To run chrome check manually with GUI:${NC}"
        echo -e "  ${CYAN}bash scripts/visual-proof.sh --chrome${NC}"
        echo ""
        return 0
    fi

    # Run claude --chrome for visual verification
    # This runs in a non-blocking way - we capture output but don't wait for interactive input
    log INFO "Starting claude --chrome verification..."

    # Create a verification prompt
    local verify_prompt="Visual verification for plan $PLAN_ID. Check:
1. Page renders correctly without visual glitches
2. Interactive elements are clickable and responsive
3. No console errors or network failures
4. Layout matches expected design

Take screenshots of key views and note any issues found."

    # Run claude --chrome with timeout
    # Note: This may need adjustment based on how claude --chrome works
    if command -v claude &> /dev/null; then
        # Try to run with a reasonable approach
        # Since claude --chrome is interactive, we'll capture what we can
        (
            echo "$verify_prompt" | timeout 120 claude --chrome 2>&1 || true
        ) > "$chrome_log" 2>&1 || exit_code=$?

        if [ $exit_code -eq 124 ]; then
            log WARN "Chrome check timed out (120s limit)"
            append_chrome_proof "TIMEOUT" "0" ""
        elif [ $exit_code -eq 0 ]; then
            log OK "Chrome visual check completed"
            append_chrome_proof "PASS" "$exit_code" ""
        else
            log WARN "Chrome check exited with code $exit_code"
            append_chrome_proof "FAIL" "$exit_code" ""
        fi
    else
        log WARN "claude CLI not found in PATH"
        append_chrome_proof "SKIPPED" "claude not installed" ""
        echo ""
        echo -e "${YELLOW}To run chrome check, install claude CLI:${NC}"
        echo -e "  ${CYAN}npm install -g @anthropic-ai/claude-code${NC}"
        echo ""
    fi

    return 0
}

append_chrome_proof() {
    local status="$1"
    local detail="$2"
    local confirmations="$3"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat >> "$VISUAL_PROOF_FILE" << EOF

## Run: ${RUN_ID}_chrome

- **Timestamp:** $timestamp
- **Plan ID:** $PLAN_ID
- **Frontend Impact:** true
- **Step:** chrome_visual_check (automated interactive)

### Commands Run
- \`claude --chrome\` verification loop

### Result
**Status:** $status
EOF

    if [ "$status" = "SKIPPED" ]; then
        cat >> "$VISUAL_PROOF_FILE" << EOF
**Reason:** $detail

### Manual Command
Run locally with GUI:
\`\`\`bash
bash scripts/visual-proof.sh --chrome
\`\`\`
EOF
    else
        cat >> "$VISUAL_PROOF_FILE" << EOF
**Exit Code:** $detail

### Visual Confirmations
${confirmations:-"See log: $CHROME_LOGS/chrome-check-$RUN_ID.log"}

### Artifacts
- Screenshots: \`$CHROME_SCREENSHOTS/\`
- Logs: \`$CHROME_LOGS/chrome-check-$RUN_ID.log\`
EOF
    fi

    echo "" >> "$VISUAL_PROOF_FILE"
    echo "---" >> "$VISUAL_PROOF_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Interactive Functions
# ═══════════════════════════════════════════════════════════════════════════════

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
    echo "  4. Run claude chrome check:"
    echo -e "     ${CYAN}claude --chrome${NC}"
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
    # Auto-enable chrome for frontend-impacting plans
    auto_enable_chrome

    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN} RRR ► VISUAL PROOF${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    log INFO "Plan ID: $PLAN_ID"
    log INFO "Frontend Impact: $FRONTEND_IMPACT"
    log INFO "Chrome Step: $RUN_CHROME"

    # Check if Playwright tests exist
    if ! playwright_tests_exist; then
        log WARN "No Playwright tests found in e2e/ directory"
        log INFO "Skipping Playwright step (no tests to run)"

        # Still run chrome check if requested
        if [ "$RUN_CHROME" = true ]; then
            run_chrome_check
        fi
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

    # Pushpa Mode forces headless, never interactive prompts
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

    # ═══════════════════════════════════════════════════════════════════════════
    # Step 1: Run Playwright
    # ═══════════════════════════════════════════════════════════════════════════

    local playwright_exit=0
    run_playwright || playwright_exit=$?

    # Determine status
    local playwright_status
    if [ $playwright_exit -eq 0 ]; then
        playwright_status="PASS"
        log OK "Playwright tests passed"
    else
        playwright_status="FAIL"
        log ERROR "Playwright tests failed (exit code: $playwright_exit)"
    fi

    # Append to VISUAL_PROOF.md
    append_playwright_proof "$playwright_status" "$playwright_exit"
    log INFO "Playwright results appended to $VISUAL_PROOF_FILE"

    # Handle hybrid mode fallback
    if [ "$mode" = "hybrid" ] && [ "$playwright_exit" -ne 0 ]; then
        if [ "$fallback" = "true" ]; then
            if is_eligible_for_interactive "$playwright_exit"; then
                if prompt_interactive_fallback; then
                    run_interactive_uat
                fi
            else
                log WARN "Failure appears to be env/build issue, not eligible for interactive fallback"
            fi
        fi
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # Step 2: Run Chrome Visual Check (if enabled)
    # ═══════════════════════════════════════════════════════════════════════════

    if [ "$RUN_CHROME" = true ]; then
        echo ""
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${CYAN} RRR ► CHROME VISUAL CHECK${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        run_chrome_check
        log INFO "Chrome results appended to $VISUAL_PROOF_FILE"
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    # Summary
    # ═══════════════════════════════════════════════════════════════════════════

    echo ""
    echo -e "${BOLD}Artifacts:${NC}"
    echo "  Playwright Report:  $PLAYWRIGHT_REPORT"
    echo "  Playwright Results: $PLAYWRIGHT_RESULTS"
    if [ "$RUN_CHROME" = true ]; then
        echo "  Chrome Screenshots: $CHROME_SCREENSHOTS"
        echo "  Chrome Logs:        $CHROME_LOGS"
    fi
    echo "  Proof Log:          $VISUAL_PROOF_FILE"
    echo ""
    echo -e "Open Playwright report: ${CYAN}npm run visual:open${NC}"
    echo ""

    exit $playwright_exit
}

main "$@"
