---
name: projecta.chrome-visual-check
description: Interactive Chrome visual verification for UI-affecting plans
tags: [testing, chrome, visual, ux, interactive]
max_lines: 180
---

# Chrome Visual Check

Interactive visual verification using Claude's Chrome browser automation. This is the final step in the verification ladder for UI_AFFECTING plans.

## When to Load

Load this skill when:
- Plan has `verification.surface: ui_affecting`
- Plan includes `chrome_visual_check` in `required_steps`
- Automated tests pass but human-level UX judgment needed
- Testing interactive flows (hover states, animations, transitions)

## Verification Ladder Position

```
1. unit_tests      → Fast, isolated logic checks
2. playwright      → Automated UI interaction tests
3. chrome_visual_check → Human-level visual verification (THIS SKILL)
```

Chrome visual check runs AFTER Playwright tests pass. It provides:
- Real browser rendering verification
- Interactive state exploration
- UX flow validation beyond what automated tests capture

## Requirements

**MUST have:**
- Claude Code with Chrome support (`claude --chrome`)
- Dev server running (typically `npm run dev`)
- Playwright tests PASSED first

**CANNOT run in:**
- Pushpa Mode (unattended overnight runs)
- Headless environments
- CI/CD pipelines

## Execution Protocol

### Step 1: Pre-flight Checks

Before running chrome visual check:

```bash
# Verify Playwright passed
grep -q "PASS" .planning/VISUAL_PROOF.md || echo "WARNING: Playwright not verified"

# Check dev server is running
curl -s http://localhost:3000 > /dev/null || npm run dev &
```

### Step 2: Run Chrome Visual Check

**Option A: Script-based (recommended)**
```bash
bash scripts/chrome-visual-check.sh [url] [description]
```

**Option B: Manual Claude Chrome**
```bash
claude --chrome
```

Then navigate to the feature and verify visually.

### Step 3: Verification Checklist

For each UI_AFFECTING plan, verify:

1. **Layout** - Elements positioned correctly
2. **Responsiveness** - Works at different viewport sizes
3. **Interactions** - Hover, click, focus states work
4. **Loading states** - Spinners, skeletons appear appropriately
5. **Error states** - Error messages display correctly
6. **Accessibility** - Tab navigation, focus indicators

### Step 4: Log Results

Append to `.planning/VISUAL_PROOF.md`:

```markdown
## Chrome Visual Check: {ISO-8601 datetime}

**Plan:** {phase}-{plan}
**URL:** {url checked}
**Viewport:** {width}x{height}

**Checklist:**
- [x] Layout correct
- [x] Responsive at mobile/tablet/desktop
- [x] Interactions work
- [x] Loading states appropriate
- [x] Error states display
- [ ] Accessibility (skipped/passed/failed)

**Result:** PASS | FAIL | PASS_WITH_NOTES

**Notes:**
{Any observations, minor issues, or recommendations}

---
```

## Skip Conditions

Chrome visual check is SKIPPED when:

1. **Pushpa Mode active** (detected via environment)
   ```bash
   if [[ -n "${PUSHPA_MODE:-}" ]]; then
     echo "SKIP: Chrome visual check disabled in Pushpa Mode"
     exit 0
   fi
   ```

2. **No display available**
   ```bash
   if [[ -z "${DISPLAY:-}" ]] && [[ "$(uname)" != "Darwin" ]]; then
     echo "SKIP: No display available"
     exit 0
   fi
   ```

3. **CI environment detected**
   ```bash
   if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
     echo "SKIP: Running in CI"
     exit 0
   fi
   ```

When skipped, log to VISUAL_PROOF.md:
```markdown
## Chrome Visual Check: {datetime}
**Plan:** {phase}-{plan}
**Result:** SKIPPED
**Reason:** {reason}
---
```

## Integration with Execute-Plan

The executor runs chrome visual check as part of verification ladder:

```
Plan execution complete
    ↓
Run unit_tests (if exist)
    ↓
Run playwright (if UI_AFFECTING)
    ↓
Run chrome_visual_check (if UI_AFFECTING + not Pushpa)
    ↓
Write SUMMARY.md
```

## Common Verification Scenarios

### Form Validation
- Submit empty form → error messages appear
- Submit invalid data → field-level errors
- Submit valid data → success state

### Navigation Flows
- Click through multi-step wizard
- Back/forward browser buttons work
- Deep links resolve correctly

### Dynamic Content
- Real-time updates appear
- Optimistic UI reverts on error
- Loading states don't flash

### Responsive Design
- Test at 375px (mobile)
- Test at 768px (tablet)
- Test at 1280px (desktop)

## Failure Handling

**If chrome visual check FAILS:**

1. Log failure details in VISUAL_PROOF.md
2. Do NOT block plan completion
3. Create follow-up task in SUMMARY.md:
   ```markdown
   ## Follow-up Required
   - [ ] Fix visual issue: {description}
   ```

Visual check failures are warnings, not blockers. The plan completes, but issues are tracked.

## Script Location

```
scripts/chrome-visual-check.sh
```

Usage:
```bash
# Basic check
bash scripts/chrome-visual-check.sh

# With specific URL
bash scripts/chrome-visual-check.sh http://localhost:3000/dashboard

# With description
bash scripts/chrome-visual-check.sh http://localhost:3000/login "Login form verification"
```
