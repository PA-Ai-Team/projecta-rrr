#!/usr/bin/env bash
#
# Vendor Vercel Agent Skills into RRR
# Pulls curated skills from vercel-labs/agent-skills into rrr/skills/community/vercel/
#
# Usage: bash scripts/vendor-vercel-skills.sh
#
# Curated skills (small, high-value for frontend work):
# - vercel-react-best-practices
# - web-design-guidelines
#
# This script is idempotent: re-running updates the target pack without
# touching other packs or any files in upstream/ or projecta/.
#
# Safety guarantees:
# - Only writes to rrr/skills/community/vercel/
# - Never touches rrr/skills/upstream/ or rrr/skills/projecta/
# - Uses targeted rm only on the specific destination directory
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

REPO_URL="https://github.com/vercel-labs/agent-skills.git"
REPO_REF="${VERCEL_SKILLS_REF:-main}"
PACK_NAME="vercel"

# Curated skills to vendor (small, high-value for frontend work)
CURATED_SKILLS=(
    "vercel-react-best-practices"
    "web-design-guidelines"
)

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

# Ensure destination is under rrr/skills/community/
if [[ "$DEST_DIR" != *"/rrr/skills/community/"* ]]; then
    echo -e "${RED}ERROR: Destination must be under rrr/skills/community/${NC}"
    echo "       Got: $DEST_DIR"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  VENDORING VERCEL AGENT SKILLS${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Source repo: $REPO_URL"
echo "Branch/ref:  $REPO_REF"
echo "Dest dir:    $DEST_DIR"
echo ""
echo "Curated skills:"
for skill in "${CURATED_SKILLS[@]}"; do
    echo "  - $skill"
done
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

# Step 2: Find skills in repo
# Vercel agent-skills repo structure may vary - look for SKILL.md or README.md
SKILLS_FOUND=()
for skill in "${CURATED_SKILLS[@]}"; do
    # Try common locations
    if [[ -d "$TMP_DIR/repo/$skill" ]]; then
        SKILLS_FOUND+=("$skill")
    elif [[ -d "$TMP_DIR/repo/skills/$skill" ]]; then
        SKILLS_FOUND+=("skills/$skill")
    elif [[ -d "$TMP_DIR/repo/packages/$skill" ]]; then
        SKILLS_FOUND+=("packages/$skill")
    else
        echo -e "${YELLOW}Warning: Skill '$skill' not found in repo${NC}"
    fi
done

if [[ ${#SKILLS_FOUND[@]} -eq 0 ]]; then
    echo -e "${RED}ERROR: No curated skills found in repository${NC}"
    echo "       Repo structure may have changed. Check: $REPO_URL"
    exit 1
fi

# Step 3: Safe targeted replace of DEST_DIR only
echo "Preparing destination..."
mkdir -p "$(dirname "$DEST_DIR")"

# Remove only the specific destination directory (safe targeted rm)
if [[ -d "$DEST_DIR" ]]; then
    echo "  Removing existing: $DEST_DIR"
    rm -rf "$DEST_DIR"
fi

# Create fresh destination
mkdir -p "$DEST_DIR"

# Step 4: Copy curated skills
echo "Copying skills..."
SKILL_COUNT=0
for skill_path in "${SKILLS_FOUND[@]}"; do
    skill_name=$(basename "$skill_path")
    src_dir="$TMP_DIR/repo/$skill_path"
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
bash scripts/vendor-vercel-skills.sh
\`\`\`
EOF

        echo -e "  ${GREEN}✓${NC} Vendored: $skill_name"
        SKILL_COUNT=$((SKILL_COUNT + 1))
    fi
done

# Step 5: Write main provenance file
cat > "$DEST_DIR/VENDORED_FROM.md" << EOF
# Vendored Vercel Agent Skills

- **Source repo:** $REPO_URL
- **Branch/ref:** $REPO_REF
- **Commit:** $COMMIT_SHA
- **Date:** $COMMIT_DATE

## Curated Skills

These skills are curated for high-value frontend/React work:

$(for skill in "${CURATED_SKILLS[@]}"; do echo "- $skill"; done)

## Note

This directory is managed by \`scripts/vendor-vercel-skills.sh\`.
Do not edit files here directly. To update, re-run the vendor script.

To update this pack:
\`\`\`bash
bash scripts/vendor-vercel-skills.sh
\`\`\`
EOF

# Step 6: Summary
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
echo "  3. Commit: git add rrr/skills/community/vercel && git commit -m 'chore: vendor Vercel agent skills'"
echo ""
