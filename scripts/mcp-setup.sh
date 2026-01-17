#!/bin/bash
#
# MCP Setup Script for Projecta RRR
# Reads MVP_FEATURES.yml and generates MCP server configuration
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Projecta RRR - MCP Setup              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Find the RRR installation directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RRR_DIR="$(dirname "$SCRIPT_DIR")"

# Check if we're in a project with .planning
PROJECT_DIR="$(pwd)"
FEATURES_FILE="$PROJECT_DIR/.planning/MVP_FEATURES.yml"
REGISTRY_FILE="$RRR_DIR/mcp.registry.json"

# Verify registry exists
if [ ! -f "$REGISTRY_FILE" ]; then
    echo -e "${RED}Error: MCP registry not found at $REGISTRY_FILE${NC}"
    exit 1
fi

# Determine which MCPs to include
MCP_SERVERS=()

# Always include default servers
DEFAULT_SERVERS=$(cat "$REGISTRY_FILE" | grep -A1000 '"defaultServers"' | grep -o '"[^"]*"' | tr -d '"' | head -10)
for server in $DEFAULT_SERVERS; do
    if [ "$server" != "defaultServers" ] && [ "$server" != "[" ] && [ "$server" != "]" ]; then
        MCP_SERVERS+=("$server")
    fi
done

# Check if MVP_FEATURES.yml exists
if [ -f "$FEATURES_FILE" ]; then
    echo -e "${GREEN}Found MVP_FEATURES.yml${NC}"
    echo ""

    # Extract preset if specified
    PRESET=$(grep "^preset:" "$FEATURES_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ' || echo "")

    if [ -n "$PRESET" ]; then
        echo -e "Preset: ${CYAN}$PRESET${NC}"

        # Get servers for this preset from registry
        PRESET_SERVERS=$(cat "$REGISTRY_FILE" | grep -A10 "\"$PRESET\":" | grep -o '"[^"]*"' | tr -d '"' | grep -v "$PRESET" | head -10)
        for server in $PRESET_SERVERS; do
            if [[ ! " ${MCP_SERVERS[*]} " =~ " ${server} " ]]; then
                MCP_SERVERS+=("$server")
            fi
        done
    fi

    # Check for specific feature selections
    # Database
    if grep -q "db:" "$FEATURES_FILE" 2>/dev/null; then
        DB=$(grep "db:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        if [ "$DB" = "neon" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " neon " ]]; then
                MCP_SERVERS+=("neon")
            fi
        fi
    fi

    # Payments
    if grep -q "payments:" "$FEATURES_FILE" 2>/dev/null; then
        PAYMENTS=$(grep "payments:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        if [ "$PAYMENTS" = "stripe" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " stripe " ]]; then
                MCP_SERVERS+=("stripe")
            fi
        fi
    fi

    # Voice
    if grep -q "voice:" "$FEATURES_FILE" 2>/dev/null; then
        VOICE=$(grep "voice:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        if [ "$VOICE" = "deepgram" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " deepgram " ]]; then
                MCP_SERVERS+=("deepgram")
            fi
        fi
    fi

    # Analytics
    if grep -q "analytics:" "$FEATURES_FILE" 2>/dev/null; then
        ANALYTICS=$(grep "analytics:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        if [ "$ANALYTICS" = "posthog" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " posthog " ]]; then
                MCP_SERVERS+=("posthog")
            fi
        fi
    fi

    # Browser automation
    if grep -q "browserAutomation:" "$FEATURES_FILE" 2>/dev/null; then
        BROWSER=$(grep "browserAutomation:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        if [ "$BROWSER" = "browserbase" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " browserbase " ]]; then
                MCP_SERVERS+=("browserbase")
            fi
        fi
    fi

    # Sandbox
    if grep -q "sandbox:" "$FEATURES_FILE" 2>/dev/null; then
        SANDBOX=$(grep "sandbox:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        if [ "$SANDBOX" = "e2b" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " e2b " ]]; then
                MCP_SERVERS+=("e2b")
            fi
        fi
    fi

    # Object storage (Cloudflare R2)
    # Normalize: r2 -> cloudflare_r2 for backward compatibility
    if grep -q "objectStorage:" "$FEATURES_FILE" 2>/dev/null; then
        STORAGE=$(grep "objectStorage:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        # Treat both "r2" and "cloudflare_r2" as Cloudflare R2
        if [ "$STORAGE" = "r2" ] || [ "$STORAGE" = "cloudflare_r2" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " cloudflare_r2 " ]]; then
                MCP_SERVERS+=("cloudflare_r2")
            fi
        fi
    fi
    # Also check object_storage (snake_case variant)
    if grep -q "object_storage:" "$FEATURES_FILE" 2>/dev/null; then
        STORAGE=$(grep "object_storage:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        # Treat both "r2" and "cloudflare_r2" as Cloudflare R2
        if [ "$STORAGE" = "r2" ] || [ "$STORAGE" = "cloudflare_r2" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " cloudflare_r2 " ]]; then
                MCP_SERVERS+=("cloudflare_r2")
            fi
        fi
    fi

    # Email
    if grep -q "email:" "$FEATURES_FILE" 2>/dev/null; then
        EMAIL=$(grep "email:" "$FEATURES_FILE" | cut -d: -f2 | tr -d ' ')
        if [ "$EMAIL" = "resend" ]; then
            if [[ ! " ${MCP_SERVERS[*]} " =~ " resend " ]]; then
                MCP_SERVERS+=("resend")
            fi
        fi
    fi
else
    echo -e "${YELLOW}No MVP_FEATURES.yml found - using SaaS default preset${NC}"
    echo ""
    # Add neon for SaaS default
    MCP_SERVERS+=("neon")
fi

echo ""
echo -e "${GREEN}MCP Servers for your stack:${NC}"
echo "─────────────────────────────"

# Output the MCP configuration
for server in "${MCP_SERVERS[@]}"; do
    # Get server details from registry
    SERVER_NAME=$(cat "$REGISTRY_FILE" | grep -A5 "\"$server\":" | grep '"name"' | cut -d'"' -f4)
    SERVER_CMD=$(cat "$REGISTRY_FILE" | grep -A5 "\"$server\":" | grep '"command"' | cut -d'"' -f4)

    if [ -n "$SERVER_CMD" ]; then
        echo -e "  ${CYAN}$server${NC}: $SERVER_NAME"
        echo -e "    Command: ${YELLOW}$SERVER_CMD${NC}"
    fi
done

echo ""
echo "─────────────────────────────"
echo ""
echo -e "${GREEN}To configure Claude Code with these MCPs:${NC}"
echo ""
echo "1. Open Claude Code settings:"
echo -e "   ${CYAN}claude config${NC}"
echo ""
echo "2. Add MCP servers manually, or add to your ~/.claude/settings.json:"
echo ""

# Generate JSON snippet
echo -e "${YELLOW}{"
echo '  "mcpServers": {'

FIRST=true
for server in "${MCP_SERVERS[@]}"; do
    SERVER_CMD=$(cat "$REGISTRY_FILE" | grep -A5 "\"$server\":" | grep '"command"' | cut -d'"' -f4)
    if [ -n "$SERVER_CMD" ]; then
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ","
        fi
        # Extract the package name from the npx command
        PKG_NAME=$(echo "$SERVER_CMD" | sed 's/npx -y //')
        echo -n "    \"$server\": {"
        echo -n "\"command\": \"npx\", \"args\": [\"-y\", \"$PKG_NAME\"]"
        echo -n "}"
    fi
done

echo ""
echo '  }'
echo -e "}${NC}"
echo ""

# List required environment variables
echo -e "${GREEN}Required environment variables:${NC}"
echo "─────────────────────────────"

for server in "${MCP_SERVERS[@]}"; do
    ENV_VARS=$(cat "$REGISTRY_FILE" | grep -A10 "\"$server\":" | grep -A5 '"envRequired"' | grep -o '"[A-Z_]*"' | tr -d '"')
    if [ -n "$ENV_VARS" ]; then
        echo -e "  ${CYAN}$server${NC}:"
        for var in $ENV_VARS; do
            echo "    - $var"
        done
    fi
done

echo ""
echo -e "${GREEN}Done!${NC} Add the environment variables to your .env file."
echo ""
