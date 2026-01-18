#!/bin/bash
#
# Chrome Visual Check for RRR
# Interactive visual verification using Claude's Chrome browser automation
#
# Usage: bash scripts/chrome-visual-check.sh [url] [description]
#
# This is the final step in the verification ladder for UI_AFFECTING plans.
# It runs AFTER Playwright tests pass and provides human-level visual verification.
#
# Skip conditions:
# - PUSHPA_MODE environment variable set
# - CI or GITHUB_ACTIONS environment variables set
# - No display available (non-Darwin without DISPLAY)
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

PLANNING_DIR=".planning"
VISUAL_PROOF_FILE="$PLANNING_DIR/VISUAL_PROOF.md"
DATETIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Arguments
URL="${1:-http://localhost:3000}"
DESCRIPTION="${2:-Interactive visual verification}"

# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

log() {
    local level="$1"
    local message="$2"
    case "$level" in
        INFO)  echo -e "${CYAN}[CHROME]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[CHROME]${NC} $message" ;;
        ERROR) echo -e "${RED}[CHROME]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[CHROME]${NC} $message" ;;
    esac
}

append_to_visual_proof() {
    local result="$1"
    local reason="${2:-}"

    # Ensure VISUAL_PROOF.md exists
    if [[ ! -f "$VISUAL_PROOF_FILE" ]]; then
        mkdir -p "$PLANNING_DIR"
        echo "# Visual Proof Log" > "$VISUAL_PROOF_FILE"
        echo "" >> "$VISUAL_PROOF_FILE"
    fi

    cat >> "$VISUAL_PROOF_FILE" << EOF

## Chrome Visual Check: ${DATETIME}

**URL:** ${URL}
**Description:** ${DESCRIPTION}
**Result:** ${result}
EOF

    if [[ -n "$reason" ]]; then
        echo "**Reason:** ${reason}" >> "$VISUAL_PROOF_FILE"
    fi

    echo "" >> "$VISUAL_PROOF_FILE"
    echo "---" >> "$VISUAL_PROOF_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Skip Condition Checks
# ═══════════════════════════════════════════════════════════════════════════════

check_skip_conditions() {
    # Check for Pushpa Mode
    if [[ -n "${PUSHPA_MODE:-}" ]]; then
        log WARN "Pushpa Mode detected - skipping chrome visual check"
        append_to_visual_proof "SKIPPED" "Pushpa Mode (unattended)"
        exit 0
    fi

    # Check for CI environment
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        log WARN "CI environment detected - skipping chrome visual check"
        append_to_visual_proof "SKIPPED" "CI environment"
        exit 0
    fi

    # Check for display availability (non-macOS)
    if [[ "$(uname)" != "Darwin" ]] && [[ -z "${DISPLAY:-}" ]]; then
        log WARN "No display available - skipping chrome visual check"
        append_to_visual_proof "SKIPPED" "No display available"
        exit 0
    fi

    # Check if Claude Chrome is available
    if ! command -v claude &> /dev/null; then
        log WARN "Claude Code not found - skipping chrome visual check"
        append_to_visual_proof "SKIPPED" "Claude Code not installed"
        exit 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Pre-flight Checks
# ═══════════════════════════════════════════════════════════════════════════════

preflight_checks() {
    log INFO "Running pre-flight checks..."

    # Check if Playwright tests passed (look for recent PASS in VISUAL_PROOF.md)
    if [[ -f "$VISUAL_PROOF_FILE" ]]; then
        if ! grep -q "PASS" "$VISUAL_PROOF_FILE" 2>/dev/null; then
            log WARN "No Playwright PASS found in VISUAL_PROOF.md"
            log WARN "Consider running 'npx playwright test' first"
        fi
    fi

    # Check if dev server is running
    if ! curl -s --connect-timeout 2 "$URL" > /dev/null 2>&1; then
        log WARN "Cannot reach $URL - is the dev server running?"
        log INFO "Try: npm run dev"

        # Ask if user wants to continue anyway
        echo -e "${YELLOW}Continue anyway? [y/N]${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log INFO "Aborting chrome visual check"
            append_to_visual_proof "SKIPPED" "Dev server not reachable"
            exit 0
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Verification Checklist
# ═══════════════════════════════════════════════════════════════════════════════

show_checklist() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD} CHROME VISUAL CHECK${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}URL:${NC} $URL"
    echo -e "${CYAN}Description:${NC} $DESCRIPTION"
    echo ""
    echo -e "${BOLD}Verification Checklist:${NC}"
    echo ""
    echo "  1. Layout       - Elements positioned correctly"
    echo "  2. Responsive   - Works at mobile/tablet/desktop"
    echo "  3. Interactions - Hover, click, focus states work"
    echo "  4. Loading      - Spinners, skeletons appear appropriately"
    echo "  5. Error states - Error messages display correctly"
    echo "  6. Accessibility- Tab navigation, focus indicators"
    echo ""
    echo -e "${BOLD}───────────────────────────────────────────────────────────────${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Interactive Mode
# ═══════════════════════════════════════════════════════════════════════════════

run_interactive_check() {
    show_checklist

    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  1) Launch Claude Chrome for interactive verification"
    echo "  2) Mark as PASS (all checks verified manually)"
    echo "  3) Mark as FAIL (issues found)"
    echo "  4) Skip this check"
    echo ""
    echo -n "Select option [1-4]: "
    read -r choice

    case "$choice" in
        1)
            log INFO "Launching Claude Chrome..."
            log INFO "Navigate to: $URL"
            log INFO "Verify the checklist items above"
            echo ""

            # Launch Claude with Chrome
            # Note: claude --chrome opens interactive Chrome session
            if claude --chrome 2>/dev/null; then
                log SUCCESS "Chrome session completed"

                # Ask for result
                echo ""
                echo -n "Did verification pass? [y/N]: "
                read -r passed
                if [[ "$passed" =~ ^[Yy]$ ]]; then
                    append_to_visual_proof "PASS"
                    log SUCCESS "Chrome visual check: PASS"
                else
                    echo -n "Enter failure notes: "
                    read -r notes
                    append_to_visual_proof "FAIL" "$notes"
                    log ERROR "Chrome visual check: FAIL"
                fi
            else
                log WARN "Claude Chrome not available or failed to launch"
                log INFO "Falling back to manual verification mode"
                run_manual_verification
            fi
            ;;
        2)
            append_to_visual_proof "PASS"
            log SUCCESS "Chrome visual check: PASS (manual verification)"
            ;;
        3)
            echo -n "Enter failure notes: "
            read -r notes
            append_to_visual_proof "FAIL" "$notes"
            log ERROR "Chrome visual check: FAIL"
            ;;
        4)
            append_to_visual_proof "SKIPPED" "User skipped"
            log INFO "Chrome visual check: SKIPPED"
            ;;
        *)
            log WARN "Invalid option, marking as skipped"
            append_to_visual_proof "SKIPPED" "Invalid option selected"
            ;;
    esac
}

run_manual_verification() {
    echo ""
    echo -e "${BOLD}Manual Verification Mode${NC}"
    echo ""
    echo "Please open $URL in your browser and verify:"
    echo ""
    echo "  [ ] Layout correct"
    echo "  [ ] Responsive at different sizes"
    echo "  [ ] Interactions work"
    echo "  [ ] Loading states appropriate"
    echo "  [ ] Error states display"
    echo "  [ ] Accessibility (tab navigation)"
    echo ""
    echo -n "Verification passed? [y/N]: "
    read -r passed

    if [[ "$passed" =~ ^[Yy]$ ]]; then
        append_to_visual_proof "PASS"
        log SUCCESS "Chrome visual check: PASS (manual)"
    else
        echo -n "Enter failure notes: "
        read -r notes
        append_to_visual_proof "FAIL" "$notes"
        log ERROR "Chrome visual check: FAIL"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    log INFO "Starting chrome visual check..."

    # Check skip conditions first
    check_skip_conditions

    # Run pre-flight checks
    preflight_checks

    # Run interactive check
    run_interactive_check

    log INFO "Results appended to $VISUAL_PROOF_FILE"
}

main "$@"
