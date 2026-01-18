---
name: rrr:overnight
description: Pushpa Mode guidance - preflight checks and safe run instructions
---

<objective>
Guide user to run Pushpa Mode safely and correctly.

Perform preflight checks and provide exact instructions.
Do NOT run Pushpa Mode directly from this command.
</objective>

<behavior>
Run these checks in order:

## 1. Check project initialization

If `.planning/STATE.md` does NOT exist:
```
## Pushpa Mode Preflight

**Status:** NOT READY

Your project is not initialized yet. Pushpa Mode requires RRR planning files.

**Fix:** Run `/rrr:new-project` first to:
- Bootstrap your project (if empty folder)
- Go through questionnaire
- Generate requirements and roadmap

Then come back and run `/rrr:overnight` again.
```
STOP here if not initialized.

## 2. Check pushpa-mode.sh exists

Check if `scripts/pushpa-mode.sh` exists in the user's project.

If it does NOT exist:
```
## Pushpa Mode Preflight

**Status:** Script not found

The Pushpa Mode script is not in your project yet.

**Fix:** Copy it from the RRR installation:

If RRR installed globally:
\`\`\`bash
mkdir -p scripts
cp ~/.claude/rrr/scripts/pushpa-mode.sh scripts/pushpa-mode.sh
chmod +x scripts/pushpa-mode.sh
\`\`\`

If RRR installed locally:
\`\`\`bash
mkdir -p scripts
cp .claude/rrr/scripts/pushpa-mode.sh scripts/pushpa-mode.sh
chmod +x scripts/pushpa-mode.sh
\`\`\`

Then run `/rrr:overnight` again.
```
STOP here if script missing.

## 3. All checks passed - provide run instructions

```
## Pushpa Mode Ready

**Status:** READY

All preflight checks passed.

### How to run

**Recommended:** Open a separate terminal (outside Claude Code) and run:

\`\`\`bash
bash scripts/pushpa-mode.sh
\`\`\`

Or if you added the npm script:
\`\`\`bash
npm run pushpa
\`\`\`

### Why run outside Claude Code?

Running Pushpa Mode inside Claude Code interactive session can:
- Trigger approval prompts that interrupt unattended execution
- Not be truly "overnight" autonomous

The script will detect if you run it inside Claude Code and prompt to confirm.

### What Pushpa Mode does

1. Plans any phases that don't have plans yet
2. Executes phases automatically (skips HITL-marked phases)
3. Runs visual proof (Playwright) after each phase
4. Enforces budgets to prevent runaway token usage
5. Generates report at `.planning/PUSHPA_REPORT.md`

### Budgets (override via env vars)

| Budget | Default | Env Var |
|--------|---------|---------|
| Max phases | 3 | `MAX_PHASES_PER_RUN` |
| Max minutes | 180 | `MAX_TOTAL_MINUTES` |
| Max RRR calls | 25 | `MAX_TOTAL_RRR_CALLS` |

### Output locations

- Report: `.planning/PUSHPA_REPORT.md`
- Logs: `.planning/logs/pushpa_*.log`
- Ledger: `.planning/pushpa/ledger.json`
- Artifacts: `.planning/artifacts/playwright/`
```
</behavior>

<constraints>
- Do NOT run pushpa-mode.sh from this command
- Only provide guidance and instructions
- Always recommend running in a separate terminal
</constraints>
