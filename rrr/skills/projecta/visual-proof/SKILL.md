---
name: projecta.visual-proof
description: Visual proof system for capturing UI verification artifacts with mandatory two-step verification
tags: [testing, playwright, chrome, artifacts, screenshots, visual, verification]
max_lines: 250
---

# Visual Proof System

## Verification Ladder

This skill covers the **mandatory two-step verification** for FRONTEND_IMPACTING plans:

```
1. unit_tests           → Fast, isolated logic checks
2. playwright           → Automated E2E tests (headless) ← Step 1
3. chrome_visual_check  → Automated interactive verification (claude --chrome) ← Step 2
```

For `frontend_impact: true` plans: Steps 2 AND 3 are MANDATORY.
For `frontend_impact: false` plans: Only unit_tests runs.

## When to Use

Load this skill when:
- Plan has `verification.frontend_impact: true`
- Plan has `verification.surface: ui_affecting`
- Verifying UI changes visually
- Running post-execution validation
- Capturing screenshots or traces for review
- Any task mentioning "visual", "screenshot", or "proof"
- Any plan touching UI/UX files (src/app, src/components, src/pages)

## Rules

### Two-Step Verification (MANDATORY for frontend_impact: true)

**Step 1: Playwright (automated headless)**
- Run: `npx playwright test` or `bash scripts/visual-proof.sh`
- Artifacts: `.planning/artifacts/playwright/`
- Append entry to VISUAL_PROOF.md

**Step 2: Chrome Visual Check (automated interactive)**
- Run: `bash scripts/visual-proof.sh --chrome`
- Uses `claude --chrome` for visual verification loop
- Artifacts: `.planning/artifacts/chrome/`
- Append SEPARATE entry to VISUAL_PROOF.md

Both steps run even when Playwright passes - we want visual/UI confirmation.

### Artifact Storage (MANDATORY)

**Playwright artifacts:**
- Test results: `.planning/artifacts/playwright/test-results/`
- HTML report: `.planning/artifacts/playwright/report/`
- Screenshots (on failure): `.planning/artifacts/playwright/test-results/`
- Traces (on failure): `.planning/artifacts/playwright/test-results/`
- Videos (on failure): `.planning/artifacts/playwright/test-results/`

**Chrome artifacts:**
- Screenshots: `.planning/artifacts/chrome/screenshots/`
- Logs: `.planning/artifacts/chrome/logs/`

**MUST:**
- Log EVERY run to `.planning/VISUAL_PROOF.md` (append-only)
- Capture screenshots on ANY test failure
- Enable trace recording for debugging failures
- Run BOTH steps for frontend_impact: true plans

**MUST NOT:**
- Delete existing VISUAL_PROOF.md entries
- Store artifacts outside `.planning/artifacts/`
- Skip visual proof after phase execution
- Skip chrome step when frontend_impact: true (unless no GUI available)

### Human Checkpoints (Key Milestones Only)

Human verification checkpoints apply for:
- Phase completion (`checkpoint:human-verify` at phase end)
- Plans tagged `milestone: true`
- Plans with auth/payment/onboarding flows

For these, add human verification checklist after automated steps complete.

## Commands

```bash
# Run full visual proof (Playwright only)
bash scripts/visual-proof.sh

# Run with chrome step (REQUIRED for frontend_impact: true)
bash scripts/visual-proof.sh --chrome

# Pushpa mode (no interactive prompts)
bash scripts/visual-proof.sh --pushpa
bash scripts/visual-proof.sh --pushpa --chrome

# Individual commands
npm run e2e                    # Headless Playwright
npm run e2e:headed             # With browser visible
npm run e2e:ui                 # Interactive UI mode

# Open HTML report
npm run visual:open
npx playwright show-report .planning/artifacts/playwright/report
```

## Environment Variables

```bash
# Frontend impact detection (set by executor)
FRONTEND_IMPACT=true           # Enables chrome step automatically

# Visual proof configuration
VISUAL_PROOF_MODE=playwright   # playwright | playwright_headed | hybrid
PLAYWRIGHT_OUTPUT_DIR=.planning/artifacts/playwright
```

## VISUAL_PROOF.md Entry Format (MANDATORY)

After EVERY test run, append an entry. Separate entries for Playwright and Chrome steps:

### Playwright Entry

```markdown
## Run: {YYYYMMDD_HHMMSS}

- **Timestamp:** {ISO-8601 datetime}
- **Plan ID:** {phase}-{plan} (or "manual run")
- **Frontend Impact:** true | false
- **Step:** playwright (automated)

### Commands Run
- `npm test` — {pass/fail/skipped}
- `npx playwright test` — {pass/fail/skipped}

### Result
**Status:** PASS | FAIL
**Exit Code:** {0 or non-zero}

### Artifacts
- Report: `.planning/artifacts/playwright/report/index.html`
- Test Results: `.planning/artifacts/playwright/test-results/`

### Console/Page/Network Errors
{List any errors observed, or "None"}

---
```

### Chrome Entry

```markdown
## Run: {YYYYMMDD_HHMMSS}

- **Timestamp:** {ISO-8601 datetime}
- **Plan ID:** {phase}-{plan}
- **Frontend Impact:** true
- **Step:** chrome_visual_check (automated interactive)

### Commands Run
- `claude --chrome` verification loop

### Result
**Status:** PASS | FAIL | SKIPPED (no GUI)

### Visual Confirmations
- {What was visually confirmed - short bullets}
- {e.g., "Login form renders correctly"}
- {e.g., "Dashboard charts load with data"}

### Artifacts
- Screenshots: `.planning/artifacts/chrome/screenshots/`
- Logs: `.planning/artifacts/chrome/logs/`

### Console/Page/Network Errors
{List any errors observed during chrome check, or "None"}

---
```

### Skipped Chrome Entry (No GUI)

```markdown
## Run: {YYYYMMDD_HHMMSS}

- **Timestamp:** {ISO-8601 datetime}
- **Plan ID:** {phase}-{plan}
- **Frontend Impact:** true
- **Step:** chrome_visual_check

### Result
**Status:** SKIPPED (no GUI available)

### Manual Command
Run locally with GUI:
\`\`\`bash
bash scripts/visual-proof.sh --chrome
\`\`\`

---
```

## Artifacts Directory Structure

```
.planning/
├── VISUAL_PROOF.md              # Append-only verification log (NEVER delete entries)
└── artifacts/
    ├── playwright/
    │   ├── report/              # HTML report (index.html)
    │   │   └── index.html
    │   └── test-results/        # Per-test artifacts
    │       ├── auth-login/
    │       │   ├── screenshot.png
    │       │   ├── trace.zip
    │       │   └── video.webm
    │       └── dashboard-view/
    │           └── screenshot.png
    └── chrome/
        ├── screenshots/         # Claude chrome visual captures
        │   └── {timestamp}-{description}.png
        └── logs/
            └── chrome-check-{timestamp}.log
```

## Playwright Configuration

Ensure `playwright.config.ts` outputs to correct location:

```typescript
export default defineConfig({
  outputDir: '.planning/artifacts/playwright/test-results',
  reporter: [
    ['html', { outputFolder: '.planning/artifacts/playwright/report' }],
    ['list']
  ],
  use: {
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
    video: 'on-first-retry',
  },
});
```

## UX Telemetry

Visual proof captures:
- Console errors (`console.error`)
- Page errors (uncaught exceptions)
- Network failures (4xx/5xx responses)
- Slow requests (>3s)

**Visual proof failure does NOT block phase completion** — logged as warning only.
However, failures MUST be recorded in VISUAL_PROOF.md for tracking.
