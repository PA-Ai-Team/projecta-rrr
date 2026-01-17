---
name: projecta.mcp-stack
description: MCP server integrations for common services
tags: [mcp, integrations, neon, stripe, posthog]
max_lines: 120
---

# MCP Stack Integrations

## When to Use

Load this skill when:
- Working with MCP servers or integrations
- Configuring external service connections
- Any task mentioning "MCP", "Neon", "Stripe", or other integrated services

## Rules

### Configuration Location

**MUST:**
- Configure MCP servers in `~/.claude/mcp.json` (global) or `.claude/mcp.json` (project)
- Reference `MVP_FEATURES.yml` for which services are enabled
- Use environment variables for secrets

**MUST NOT:**
- Hardcode API keys in mcp.json
- Enable services not listed in MVP_FEATURES.yml

### Available MCP Servers

| Service | Package | Purpose |
|---------|---------|---------|
| Neon | `@neondatabase/mcp-server-neon` | PostgreSQL database |
| Stripe | `@anthropics/mcp-server-stripe` | Payments |
| PostHog | `posthog-mcp-server` | Analytics |
| Deepgram | `@anthropics/mcp-server-deepgram` | Speech-to-text |
| Browserbase | `@anthropics/mcp-server-browserbase` | Browser automation |
| E2B | `@anthropics/mcp-server-e2b` | Code execution |

### Configuration Format

```json
{
  "mcpServers": {
    "neon": {
      "command": "npx",
      "args": ["-y", "@neondatabase/mcp-server-neon"],
      "env": {
        "NEON_API_KEY": "${NEON_API_KEY}"
      }
    },
    "stripe": {
      "command": "npx",
      "args": ["-y", "@anthropics/mcp-server-stripe"],
      "env": {
        "STRIPE_SECRET_KEY": "${STRIPE_SECRET_KEY}"
      }
    }
  }
}
```

### MVP_FEATURES.yml Reference

Check which services are enabled for this project:

```yaml
# MVP_FEATURES.yml
database:
  provider: neon
  enabled: true

payments:
  provider: stripe
  enabled: true

analytics:
  provider: posthog
  enabled: false
```

Only configure MCP servers for enabled services.

### Service-Specific Notes

**Neon (PostgreSQL):**
- Use for all database operations
- Supports branching for dev/staging
- Connection string in `DATABASE_URL`

**Stripe:**
- Use test mode keys during development
- Webhook endpoint at `/api/webhooks/stripe`
- Products/prices created via MCP or dashboard

**PostHog:**
- Track events with `posthog.capture()`
- Feature flags via `posthog.isFeatureEnabled()`
- Session recording optional

**Cloudflare R2:**
- See `projecta.cloudflare-r2` skill for configuration
- Uses S3-compatible SDK

## Environment Variables

```bash
# Database
DATABASE_URL=postgresql://...
NEON_API_KEY=

# Payments
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PUBLISHABLE_KEY=pk_test_...

# Analytics
NEXT_PUBLIC_POSTHOG_KEY=
NEXT_PUBLIC_POSTHOG_HOST=

# Storage (see cloudflare-r2 skill)
CLOUDFLARE_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=
```

## Setup Script

Run MCP setup after project initialization:

```bash
bash scripts/mcp-setup.sh
# or
npm run mcp:setup
```

This script:
1. Detects services from MVP_FEATURES.yml
2. Creates/updates mcp.json
3. Validates required env vars
