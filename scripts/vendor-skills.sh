#!/bin/bash
# Vendor Anthropic skills into RRR repo
# Run by maintainers only, not during user install

set -e

UPSTREAM_REPO="https://github.com/anthropics/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$REPO_ROOT/rrr/skills/upstream/anthropic"
TMP_DIR="/tmp/anthropic-skills-$$"

echo "Vendoring Anthropic skills..."
echo "  Source: $UPSTREAM_REPO"
echo "  Target: $VENDOR_DIR"
echo ""

# Clean up on exit
trap "rm -rf $TMP_DIR" EXIT

# Clone fresh
echo "Cloning upstream repository..."
git clone --depth 1 "$UPSTREAM_REPO" "$TMP_DIR" 2>/dev/null

SHA=$(cd "$TMP_DIR" && git rev-parse HEAD)
DATE=$(date +%Y-%m-%d)

echo "  Commit: $SHA"
echo "  Date: $DATE"
echo ""

# Clear existing and recreate
rm -rf "$VENDOR_DIR"
mkdir -p "$VENDOR_DIR"

# Copy all skills
SKILL_COUNT=0
for skill in "$TMP_DIR/skills/"*/; do
  if [ -d "$skill" ]; then
    skill_name=$(basename "$skill")

    # Copy skill directory
    cp -r "$skill" "$VENDOR_DIR/$skill_name"

    # Add provenance file
    cat > "$VENDOR_DIR/$skill_name/VENDORED_FROM.md" << EOF
# Vendored Skill

- **Source:** $UPSTREAM_REPO
- **Commit:** $SHA
- **Date:** $DATE
- **Note:** Snapshot - do not edit. Update by re-running vendor script.
EOF

    echo "  Vendored: $skill_name"
    SKILL_COUNT=$((SKILL_COUNT + 1))
  fi
done

echo ""
echo "Done! Vendored $SKILL_COUNT skills from $UPSTREAM_REPO @ ${SHA:0:7}"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff rrr/skills/upstream/anthropic"
echo "  2. Update registry.json if new skills were added"
echo "  3. Commit: git add rrr/skills/upstream && git commit -m 'chore: vendor upstream skills'"
