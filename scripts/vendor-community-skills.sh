#!/usr/bin/env bash
#
# Vendor Community Skills into RRR
# Pulls skills from community repos into rrr/skills/community/
#
# Usage: bash scripts/vendor-community-skills.sh
#
# This script is idempotent: re-running updates the target pack without
# touching other packs or any files in upstream/ or projecta/.
#
# Safety guarantees:
# - Only writes to rrr/skills/community/<pack-name>/
# - Never touches rrr/skills/upstream/ or rrr/skills/projecta/
# - Uses targeted rm only on the specific destination directory
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration (defaults)
# ═══════════════════════════════════════════════════════════════════════════════

REPO_URL="${REPO_URL:-https://github.com/ovachiever/droid-tings.git}"
REPO_REF="${REPO_REF:-master}"
SOURCE_SUBDIR="${SOURCE_SUBDIR:-skills}"
PACK_NAME="${PACK_NAME:-droid-tings}"

# Derived paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DEST_DIR="$REPO_ROOT/rrr/skills/community/$PACK_NAME"

# Temp directory for clone
TMP_DIR="$(mktemp -d)"

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
    echo "ERROR: Destination path contains protected directory (upstream/ or projecta/)"
    echo "       Community skills must go to rrr/skills/community/ only"
    exit 1
fi

# Ensure destination is under rrr/skills/community/
if [[ "$DEST_DIR" != *"/rrr/skills/community/"* ]]; then
    echo "ERROR: Destination must be under rrr/skills/community/"
    echo "       Got: $DEST_DIR"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

echo "Vendoring community skills..."
echo "  Source repo: $REPO_URL"
echo "  Branch/ref:  $REPO_REF"
echo "  Source dir:  $SOURCE_SUBDIR"
echo "  Dest dir:    $DEST_DIR"
echo ""

# Step 1: Clone repo (shallow)
echo "Cloning repository..."
if ! git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_DIR/repo" 2>/dev/null; then
    echo "ERROR: Failed to clone $REPO_URL (branch: $REPO_REF)"
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
    echo "ERROR: Source subdirectory not found: $SOURCE_SUBDIR"
    echo "       Expected at: $SOURCE_PATH"
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

# Copy source contents
echo "Copying skills..."
cp -R "$SOURCE_PATH"/* "$DEST_DIR/"

# Step 4: Write provenance files

# Main VENDORED_FROM.md at pack root
cat > "$DEST_DIR/VENDORED_FROM.md" << EOF
# Vendored Community Skills Pack

- **Source repo:** $REPO_URL
- **Branch/ref:** $REPO_REF
- **Commit:** $COMMIT_SHA
- **Date:** $COMMIT_DATE
- **Source subdir:** $SOURCE_SUBDIR

## Note

This directory is managed by \`scripts/vendor-community-skills.sh\`.
Do not edit files here directly. To update, re-run the vendor script.

To update this pack:
\`\`\`bash
bash scripts/vendor-community-skills.sh
\`\`\`
EOF

# Per-skill VENDORED_FROM.md
SKILL_COUNT=0
for skill_dir in "$DEST_DIR"/*/; do
    if [[ -d "$skill_dir" ]]; then
        skill_name=$(basename "$skill_dir")

        cat > "$skill_dir/VENDORED_FROM.md" << EOF
# Vendored Skill

- **Pack:** $PACK_NAME
- **Skill:** $skill_name
- **Source repo:** $REPO_URL
- **Branch/ref:** $REPO_REF
- **Commit:** $COMMIT_SHA
- **Date:** $COMMIT_DATE

**Do not edit.** Re-vendor to update:
\`\`\`bash
bash scripts/vendor-community-skills.sh
\`\`\`
EOF

        echo "  Vendored: $skill_name"
        SKILL_COUNT=$((SKILL_COUNT + 1))
    fi
done

# Step 5: Summary
echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "Done! Vendored $SKILL_COUNT skills from $PACK_NAME"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo "  Source: $REPO_URL @ ${COMMIT_SHA:0:7}"
echo "  Dest:   $DEST_DIR"
echo ""
echo "Next steps:"
echo "  1. Review: ls -la $DEST_DIR"
echo "  2. Check provenance: cat $DEST_DIR/VENDORED_FROM.md"
echo "  3. Commit: git add rrr/skills/community && git commit -m 'chore: vendor community skills ($PACK_NAME)'"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# Validation steps (run manually after script)
# ═══════════════════════════════════════════════════════════════════════════════
#
# 1. Run the script:
#    bash scripts/vendor-community-skills.sh
#
# 2. List vendored skills:
#    ls -la rrr/skills/community/droid-tings
#
# 3. Check provenance:
#    cat rrr/skills/community/droid-tings/VENDORED_FROM.md
#
# 4. Verify upstream/projecta are untouched:
#    git status rrr/skills/upstream/
#    git status rrr/skills/projecta/
#    # Should show no changes
#
# 5. Re-run to verify idempotency:
#    bash scripts/vendor-community-skills.sh
#    # Should complete successfully, updating only droid-tings
#
