---
name: rrr:install-skill
description: Install a skill from GitHub or marketplace
argument-hint: "<github-url-or-skill-name>"
---

<objective>
Fetch and install a skill from an external source into the community skills directory.

Usage:
  /rrr:install-skill <github-url>
  /rrr:install-skill <skill-name>  (searches skillsmp.com)
</objective>

<process>

## Step 1: Parse Input

Determine input type:

**GitHub URL** (contains "github.com"):
```
https://github.com/user/repo/blob/main/skills/my-skill/SKILL.md
https://github.com/user/repo/tree/main/my-skill
```

**Skill name** (plain text):
```
my-skill-name
awesome-react-patterns
```

## Step 2: Resolve Source

**For GitHub URL:**
1. Extract raw file URL
2. Convert: `github.com/user/repo/blob/branch/path` → `raw.githubusercontent.com/user/repo/branch/path`
3. Fetch SKILL.md content

**For skill name:**
1. Search skillsmp.com: `https://skillsmp.com/api/search?q={name}`
2. Present top 3 results to user
3. User selects one
4. Get GitHub URL from selection

## Step 3: Fetch and Validate

1. Fetch SKILL.md content from resolved URL
2. Validate format:
   - Has YAML frontmatter with `name`, `description`
   - Has content sections (rules, commands, etc.)
   - Reasonable size (< 500 lines)

If validation fails, report specific issues and abort.

## Step 4: Extract Skill Name

From frontmatter:
```yaml
---
name: community.skill-name
description: What this skill does
tags: [tag1, tag2]
max_lines: 100
---
```

If no name in frontmatter, derive from URL path or ask user.

## Step 5: Save to Community Directory

Determine install location:
- Local project: `./.claude/skills/community/`
- Global: `~/.claude/skills/community/`

Default to local if `.claude/` exists in current directory.

Create directory and save:
```
.claude/skills/community/{skill-name}/
├── SKILL.md
└── INSTALLED_FROM.md  (provenance record)
```

INSTALLED_FROM.md content:
```markdown
# Installed Skill

- **Source:** {github-url}
- **Installed:** {date}
- **By:** /rrr:install-skill
```

## Step 6: Update Local Registry

Add entry to local registry override (create if needed):

```bash
# Check for local registry
if [ -f ".claude/skills/registry.local.json" ]; then
  # Merge new skill into existing
else
  # Create new local registry
fi
```

Local registry format:
```json
{
  "skills": {
    "community.skill-name": {
      "path": "community/skill-name/SKILL.md",
      "tags": ["from", "frontmatter"],
      "max_lines": 100,
      "vendored": false,
      "source": "https://github.com/user/repo/..."
    }
  }
}
```

## Step 7: Confirm Installation

```
✓ Installed: community.skill-name

Location: .claude/skills/community/skill-name/SKILL.md
Source: https://github.com/user/repo/...

To use in PLAN.md frontmatter:
---
skills:
  - community.skill-name
---

To list all skills: /rrr:list-skills
```

</process>

<error_handling>

**Network error:**
```
Failed to fetch skill from {url}
Error: {message}

Try:
  - Check the URL is accessible
  - Ensure the file is public
  - Try again later
```

**Invalid format:**
```
Skill validation failed: {reason}

Expected format:
---
name: skill-name
description: What it does
tags: [tag1, tag2]
---

# Skill Title

## Rules
...
```

**Already installed:**
```
Skill already installed: community.skill-name

To reinstall: delete .claude/skills/community/{name}/ and try again
```

</error_handling>

<success_criteria>
- [ ] Skill fetched from source
- [ ] Format validated
- [ ] Saved to community directory
- [ ] Provenance recorded
- [ ] Local registry updated
- [ ] User informed of usage
</success_criteria>
