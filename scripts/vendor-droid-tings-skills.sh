#!/usr/bin/env bash
#
# Vendor droid-tings Skills into RRR
# Pulls skills from ovachiever/droid-tings into rrr/skills/community/droid-tings/
#
# Usage:
#   # Dry run (show available skills, don't copy)
#   bash scripts/vendor-droid-tings-skills.sh --list
#
#   # Vendor specific skills only (recommended to avoid bloat)
#   DROID_TINGS_ALLOWLIST="axolotl,unsloth,deepspeed" bash scripts/vendor-droid-tings-skills.sh
#
#   # Vendor ALL skills (warning: large, ~40MB)
#   DROID_TINGS_ALL=true bash scripts/vendor-droid-tings-skills.sh
#
# Environment:
#   DROID_TINGS_ALLOWLIST  Comma-separated list of skill names to vendor
#   DROID_TINGS_ALL        Set to "true" to vendor all skills (large!)
#   DROID_TINGS_REF        Git ref to clone (default: master)
#
# Safety guarantees:
# - Only writes to rrr/skills/community/droid-tings/
# - Never touches rrr/skills/upstream/ or rrr/skills/projecta/
# - By default vendors NOTHING without explicit allowlist or --all flag
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

REPO_URL="https://github.com/ovachiever/droid-tings.git"
REPO_REF="${DROID_TINGS_REF:-master}"
SOURCE_SUBDIR="skills"
PACK_NAME="droid-tings"

# Derived paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DEST_DIR="$REPO_ROOT/rrr/skills/community/$PACK_NAME"

# Temp directory for clone
TMP_DIR="$(mktemp -d)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Flags
LIST_ONLY=false

# ═══════════════════════════════════════════════════════════════════════════════
# Parse arguments
# ═══════════════════════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
    case $1 in
        --list|-l)
            LIST_ONLY=true
            shift
            ;;
        --all|-a)
            export DROID_TINGS_ALL=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# Cleanup trap
# ═══════════════════════════════════════════════════════════════════════════════

cleanup() {
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# Safety checks
# ═══════════════════════════════════════════════════════════════════════════════

# Ensure we're not accidentally targeting protected directories
if [[ "$DEST_DIR" == *"/upstream/"* ]] || [[ "$DEST_DIR" == *"/projecta/"* ]]; then
    echo -e "${RED}ERROR: Destination path contains protected directory (upstream/ or projecta/)${NC}"
    echo "       Community skills must go to rrr/skills/community/ only"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  VENDORING DROID-TINGS SKILLS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Source repo: $REPO_URL"
echo "Branch/ref:  $REPO_REF"
echo "Dest dir:    $DEST_DIR"
echo ""

# Step 1: Clone repo (shallow)
echo "Cloning repository..."
if ! git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_DIR/repo" 2>/dev/null; then
    echo -e "${RED}ERROR: Failed to clone $REPO_URL (branch: $REPO_REF)${NC}"
    exit 1
fi

# Get commit info
COMMIT_SHA=$(cd "$TMP_DIR/repo" && git rev-parse HEAD)
COMMIT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "  Commit: ${COMMIT_SHA:0:7}"
echo ""

# Step 2: Verify source subdir exists
SOURCE_PATH="$TMP_DIR/repo/$SOURCE_SUBDIR"
if [[ ! -d "$SOURCE_PATH" ]]; then
    echo -e "${RED}ERROR: Source subdirectory not found: $SOURCE_SUBDIR${NC}"
    echo "       Expected at: $SOURCE_PATH"
    exit 1
fi

# Step 3: Get list of available skills
AVAILABLE_SKILLS=()
for skill_dir in "$SOURCE_PATH"/*/; do
    if [[ -d "$skill_dir" ]]; then
        skill_name=$(basename "$skill_dir")
        AVAILABLE_SKILLS+=("$skill_name")
    fi
done

echo "Available skills (${#AVAILABLE_SKILLS[@]} total):"
for skill in "${AVAILABLE_SKILLS[@]}"; do
    # Get size estimate
    skill_size=$(du -sh "$SOURCE_PATH/$skill" 2>/dev/null | cut -f1 || echo "?")
    echo "  - $skill ($skill_size)"
done
echo ""

# Handle list-only mode
if [[ "$LIST_ONLY" == true ]]; then
    echo -e "${CYAN}List mode: No skills vendored${NC}"
    echo ""
    echo "To vendor specific skills:"
    echo -e "  ${GREEN}DROID_TINGS_ALLOWLIST=\"skill1,skill2\" bash scripts/vendor-droid-tings-skills.sh${NC}"
    echo ""
    echo "To vendor all skills (warning: large!):"
    echo -e "  ${YELLOW}DROID_TINGS_ALL=true bash scripts/vendor-droid-tings-skills.sh${NC}"
    echo ""
    exit 0
fi

# Step 4: Determine which skills to vendor
SKILLS_TO_VENDOR=()

if [[ "${DROID_TINGS_ALL:-}" == "true" ]]; then
    echo -e "${YELLOW}WARNING: Vendoring ALL skills (this is large!)${NC}"
    SKILLS_TO_VENDOR=("${AVAILABLE_SKILLS[@]}")
elif [[ -n "${DROID_TINGS_ALLOWLIST:-}" ]]; then
    echo "Using allowlist: $DROID_TINGS_ALLOWLIST"
    IFS=',' read -ra ALLOWLIST <<< "$DROID_TINGS_ALLOWLIST"
    for skill in "${ALLOWLIST[@]}"; do
        skill=$(echo "$skill" | tr -d ' ')  # trim whitespace
        if [[ " ${AVAILABLE_SKILLS[*]} " =~ " $skill " ]]; then
            SKILLS_TO_VENDOR+=("$skill")
        else
            echo -e "${YELLOW}Warning: Skill '$skill' not found in repo${NC}"
        fi
    done
else
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  NO SKILLS VENDORED (allowlist required)${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "To prevent npm bloat, you must specify which skills to vendor:"
    echo ""
    echo "Option 1: Vendor specific skills"
    echo -e "  ${GREEN}DROID_TINGS_ALLOWLIST=\"axolotl,unsloth\" bash scripts/vendor-droid-tings-skills.sh${NC}"
    echo ""
    echo "Option 2: List available skills first"
    echo -e "  ${CYAN}bash scripts/vendor-droid-tings-skills.sh --list${NC}"
    echo ""
    echo "Option 3: Vendor all (not recommended for npm)"
    echo -e "  ${YELLOW}DROID_TINGS_ALL=true bash scripts/vendor-droid-tings-skills.sh${NC}"
    echo ""
    exit 0
fi

if [[ ${#SKILLS_TO_VENDOR[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR: No valid skills to vendor${NC}"
    exit 1
fi

echo ""
echo "Skills to vendor (${#SKILLS_TO_VENDOR[@]}):"
for skill in "${SKILLS_TO_VENDOR[@]}"; do
    echo "  - $skill"
done
echo ""

# Step 5: Safe targeted replace of DEST_DIR only
echo "Preparing destination..."
mkdir -p "$(dirname "$DEST_DIR")"

# Remove only the specific destination directory (safe targeted rm)
if [[ -d "$DEST_DIR" ]]; then
    echo "  Removing existing: $DEST_DIR"
    rm -rf "$DEST_DIR"
fi

# Create fresh destination
mkdir -p "$DEST_DIR"

# Step 6: Copy selected skills
echo "Copying skills..."
SKILL_COUNT=0
for skill_name in "${SKILLS_TO_VENDOR[@]}"; do
    src_dir="$SOURCE_PATH/$skill_name"
    dest_skill_dir="$DEST_DIR/$skill_name"

    if [[ -d "$src_dir" ]]; then
        cp -R "$src_dir" "$dest_skill_dir"

        # Add per-skill VENDORED_FROM.md
        cat > "$dest_skill_dir/VENDORED_FROM.md" << EOF
# Vendored Skill

- **Pack:** $PACK_NAME
- **Skill:** $skill_name
- **Source repo:** $REPO_URL
- **Branch/ref:** $REPO_REF
- **Commit:** $COMMIT_SHA
- **Date:** $COMMIT_DATE

**Do not edit.** Re-vendor to update:
\`\`\`bash
DROID_TINGS_ALLOWLIST="$skill_name" bash scripts/vendor-droid-tings-skills.sh
\`\`\`
EOF

        echo -e "  ${GREEN}✓${NC} Vendored: $skill_name"
        SKILL_COUNT=$((SKILL_COUNT + 1))
    fi
done

# Step 7: Write main provenance file
cat > "$DEST_DIR/VENDORED_FROM.md" << EOF
# Vendored droid-tings Skills Pack

- **Source repo:** $REPO_URL
- **Branch/ref:** $REPO_REF
- **Commit:** $COMMIT_SHA
- **Date:** $COMMIT_DATE
- **Source subdir:** $SOURCE_SUBDIR

## Vendored Skills

$(for skill in "${SKILLS_TO_VENDOR[@]}"; do echo "- $skill"; done)

## Note

This directory is managed by \`scripts/vendor-droid-tings-skills.sh\`.
Do not edit files here directly. To update, re-run the vendor script.

To update this pack:
\`\`\`bash
DROID_TINGS_ALLOWLIST="${SKILLS_TO_VENDOR[*]// /,}" bash scripts/vendor-droid-tings-skills.sh
\`\`\`

To add more skills:
\`\`\`bash
bash scripts/vendor-droid-tings-skills.sh --list
DROID_TINGS_ALLOWLIST="existing,new_skill" bash scripts/vendor-droid-tings-skills.sh
\`\`\`
EOF

# Step 8: Summary
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Done! Vendored $SKILL_COUNT skills from $PACK_NAME${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Source: $REPO_URL @ ${COMMIT_SHA:0:7}"
echo "  Dest:   $DEST_DIR"
echo ""
echo "Next steps:"
echo "  1. Review: ls -la $DEST_DIR"
echo "  2. Check provenance: cat $DEST_DIR/VENDORED_FROM.md"
echo "  3. Commit: git add rrr/skills/community/$PACK_NAME && git commit -m 'chore: vendor droid-tings skills'"
echo ""
