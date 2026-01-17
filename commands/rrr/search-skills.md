---
name: rrr:search-skills
description: Search for skills on skillsmp.com marketplace
argument-hint: "<search-query>"
---

<objective>
Search the skillsmp.com marketplace for community skills matching a query.
Present results and offer to install selected skill.
</objective>

<process>

## Step 1: Parse Query

Extract search query from $ARGUMENTS.

If no query provided:
```
Usage: /rrr:search-skills <query>

Examples:
  /rrr:search-skills react patterns
  /rrr:search-skills database migrations
  /rrr:search-skills typescript best practices
```

## Step 2: Search Marketplace

Query skillsmp.com API:

```bash
curl -s "https://skillsmp.com/api/search?q=${QUERY}&limit=10"
```

Expected response format:
```json
{
  "results": [
    {
      "name": "skill-name",
      "description": "What it does",
      "author": "username",
      "stars": 42,
      "url": "https://github.com/user/repo/...",
      "tags": ["tag1", "tag2"]
    }
  ],
  "total": 156
}
```

## Step 3: Present Results

```markdown
# Skill Search: "{query}"

Found {total} skills. Showing top 10:

| # | Skill | Description | Stars |
|---|-------|-------------|-------|
| 1 | **react-patterns** by @user | React design patterns | ⭐ 142 |
| 2 | **api-design** by @other | REST API conventions | ⭐ 89 |
| 3 | **testing-utils** by @dev | Testing utilities | ⭐ 67 |
| ... | ... | ... | ... |

---

To install a skill, run:
  `/rrr:install-skill <number>` or `/rrr:install-skill <skill-name>`

To see more results:
  `/rrr:search-skills {query} --page 2`
```

## Step 4: Handle Selection

If user responds with a number or skill name:

1. Look up the skill from cached results
2. Route to `/rrr:install-skill` with the skill's GitHub URL

## Step 5: No Results Handling

```markdown
# Skill Search: "{query}"

No skills found matching "{query}".

Try:
- Different keywords
- Broader search terms
- Check spelling

Popular categories:
- `/rrr:search-skills react`
- `/rrr:search-skills testing`
- `/rrr:search-skills api`
- `/rrr:search-skills database`
```

</process>

<fallback>
If skillsmp.com is unavailable:

```markdown
# Skill Search Unavailable

Could not reach skillsmp.com marketplace.

Alternative: Install directly from GitHub:
  `/rrr:install-skill https://github.com/user/repo/blob/main/SKILL.md`

Browse skills manually:
  https://skillsmp.com
```
</fallback>

<notes>
- Cache search results for quick install selection
- Show star count as popularity indicator
- Paginate results (10 per page)
- Include author for attribution
</notes>
