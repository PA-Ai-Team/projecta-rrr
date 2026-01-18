# Community Skills

Community skills are optional skill packs from third-party repositories. They are vendored (copied) into this directory using scripts.

## Available Vendor Scripts

### Vercel Agent Skills (Recommended for Frontend)

Small, curated skills for React/Next.js best practices:

```bash
bash scripts/vendor-vercel-skills.sh
```

Vendors:
- `vercel-react-best-practices` - React patterns and conventions
- `web-design-guidelines` - UI/UX design principles

### droid-tings Skills

Large collection of AI/ML focused skills. **Not vendored by default** to keep npm package lean.

```bash
# List available skills
bash scripts/vendor-droid-tings-skills.sh --list

# Vendor specific skills only
DROID_TINGS_ALLOWLIST="axolotl,unsloth" bash scripts/vendor-droid-tings-skills.sh

# Vendor all (warning: 40+ MB)
DROID_TINGS_ALL=true bash scripts/vendor-droid-tings-skills.sh
```

## npm Package Policy

To keep the published npm package lean:

| Pack | Included in npm | Size |
|------|-----------------|------|
| `projecta/*` | Yes | ~50 KB |
| `upstream/anthropic/*` | Yes | ~200 KB |
| `community/vercel/*` | Yes | ~20 KB |
| `community/droid-tings/*` | **No** | ~40 MB |

Large packs like droid-tings are excluded from npm but available for local vendoring.

## Syncing Community Skills

Community skills should be synced periodically to get updates:

```bash
# Update Vercel skills
bash scripts/vendor-vercel-skills.sh

# Update droid-tings (if you have them locally)
DROID_TINGS_ALLOWLIST="your,skills" bash scripts/vendor-droid-tings-skills.sh
```

After vendoring, commit the changes:

```bash
git add rrr/skills/community/
git commit -m "chore: sync community skills"
```

## Adding Custom Community Skills

To add skills from other repositories, create a new vendor script following the pattern in `scripts/vendor-*.sh`. Key requirements:

1. Clone the source repo to a temp directory
2. Copy only to `rrr/skills/community/<pack-name>/`
3. Never touch `upstream/` or `projecta/`
4. Write `VENDORED_FROM.md` provenance files
5. Clean up temp directory on exit
