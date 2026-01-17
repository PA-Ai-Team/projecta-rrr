---
name: rrr:list-skills
description: List all available skills (vendored and community)
---

<objective>
Display all available skills organized by category:
- Vendored Anthropic skills
- Vendored Projecta skills
- Community (user-installed) skills

Output skills with name, description, and tags for easy reference.
</objective>

<process>

## Step 1: Locate Skills Directory

Check locations in order:
1. `./.claude/skills/` (local)
2. `~/.claude/skills/` (global)

## Step 2: Load Registry

```bash
# Main registry
SKILLS_DIR=$(find_skills_dir)
cat "$SKILLS_DIR/registry.json"

# Local overrides (if exists)
cat "$SKILLS_DIR/registry.local.json" 2>/dev/null
```

## Step 3: Scan Community Skills

```bash
ls -1 "$SKILLS_DIR/community/" 2>/dev/null
```

For each community skill, read frontmatter to get description and tags.

## Step 4: Format Output

```markdown
# RRR Skills

## Projecta Skills (Default Stack)

| Skill | Description | Tags |
|-------|-------------|------|
| `projecta.nextjs-typescript` ⭐ | Next.js App Router + TypeScript | framework, nextjs, typescript |
| `projecta.testing` | Vitest + Playwright testing | testing, vitest, playwright |
| `projecta.visual-proof` | Visual proof artifact capture | testing, artifacts |
| `projecta.shadcn-ui` | shadcn/ui components | ui, tailwind |
| `projecta.cloudflare-r2` | Cloudflare R2 storage | storage, r2 |
| `projecta.mcp-stack` | MCP server integrations | mcp, integrations |

⭐ = Default skill (loads automatically)

## Anthropic Skills (Vendored)

| Skill | Description | Tags |
|-------|-------------|------|
| `anthropic.pdf` | PDF document handling | documents, pdf |
| `anthropic.xlsx` | Excel spreadsheet handling | documents, excel |
| `anthropic.webapp-testing` | Web application testing | testing, webapp |
| ... | ... | ... |

## Community Skills (Installed)

| Skill | Description | Source |
|-------|-------------|--------|
| `community.my-skill` | Custom skill | github.com/user/repo |

No community skills installed.
To install: `/rrr:install-skill <github-url-or-name>`

---

## Usage

Add skills to PLAN.md frontmatter:

```yaml
---
skills:
  - projecta.testing
  - projecta.visual-proof
  - anthropic.webapp-testing
---
```

Skills load into executor context at plan execution time.

**Limits:**
- Max 10 skills per plan
- Max 1000 lines total

**Default:** `projecta.nextjs-typescript` loads automatically.
Add `skills_mode: minimal` to skip default.
```

</process>

<notes>
- Skills marked with ⭐ load automatically
- Show skill count summary at bottom
- If no community skills, show install instructions
- Link to search command for discovering more
</notes>
