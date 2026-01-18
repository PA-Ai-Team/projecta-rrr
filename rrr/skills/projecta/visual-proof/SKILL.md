---
name: projecta.visual-proof
description: Visual proof system for capturing UI verification artifacts
tags: [testing, playwright, artifacts, screenshots, visual]
max_lines: 150
---

# Visual Proof System

## When to Use

Load this skill when:
- Verifying UI changes visually
- Running post-execution validation
- Capturing screenshots or traces for review
- Any task mentioning "visual", "screenshot", or "proof"
- Any plan touching UI/UX files (src/app, src/components, src/pages)

## Rules

### Artifact Storage (MANDATORY)

**MUST:**
- Store ALL Playwright artifacts in `.planning/artifacts/playwright/`:
  - Test results: `.planning/artifacts/playwright/test-results/`
  - HTML report: `.planning/artifacts/playwright/report/`
  - Screenshots (on failure): `.planning/artifacts/playwright/test-results/`
  - Traces (on failure): `.planning/artifacts/playwright/test-results/`
  - Videos (on failure): `.planning/artifacts/playwright/test-results/`
- Log EVERY run to `.planning/VISUAL_PROOF.md` (append-only)
- Capture screenshots on ANY test failure
- Enable trace recording for debugging failures

**MUST NOT:**
- Delete existing VISUAL_PROOF.md entries
- Store artifacts outside `.planning/artifacts/`
- Skip visual proof after phase execution
- Overwrite previous run artifacts without archiving

### Interactive Verification (UX-Sensitive Plans)

**When to recommend interactive verification:**
- Plan has `checkpoint:human-verify` task type
- Plan mentions UX-sensitive keywords: flow, animation, transition, hover, responsive, accessibility
- User explicitly requests visual review
- Previous automated tests failed with UI-related errors

**Interactive verification options (in order of preference):**

1. **Playwright UI mode** (preferred for exploratory testing):
   ```bash
   npx playwright test --ui
   ```
   Opens interactive test runner with visual inspection.

2. **Headed mode** (see tests execute):
   ```bash
   npx playwright test --headed
   ```

3. **Claude chrome browser** (optional for deep UX exploration):
   ```bash
   claude --chrome
   ```
   Use for conversational UX verification when automated tests pass but human judgment needed.

### Running Visual Proof

After implementation tasks complete (BEFORE writing SUMMARY.md):

1. Check for `e2e/*.spec.ts` files
2. Run unit tests if they exist: `npm run test:unit` or `npm test`
3. Run e2e tests: `npx playwright test`
4. Confirm artifact locations exist:
   - `.planning/artifacts/playwright/test-results/`
   - `.planning/artifacts/playwright/report/`
5. Append run record to `.planning/VISUAL_PROOF.md`
6. If failures occurred, ensure screenshots/traces/videos captured

**Always append to VISUAL_PROOF.md** after running tests, regardless of pass/fail.

## Commands

```bash
# Run visual proof (full suite)
bash scripts/visual-proof.sh

# Run Playwright tests
npm run e2e                    # Headless
npm run e2e:headed             # With browser visible
npm run e2e:ui                 # Interactive UI mode

# Open HTML report
npm run visual:open
# or
npx playwright show-report .planning/artifacts/playwright/report

# Run specific test file
npx playwright test e2e/auth.spec.ts

# Debug a failing test
npx playwright test --debug e2e/auth.spec.ts
```

## Environment Variables

```bash
# Visual proof configuration
VISUAL_PROOF_MODE=playwright     # playwright | playwright_headed | hybrid
PLAYWRIGHT_OUTPUT_DIR=.planning/artifacts/playwright
```

## Artifacts Directory Structure

```
.planning/
├── VISUAL_PROOF.md              # Append-only run log (NEVER delete entries)
└── artifacts/
    └── playwright/
        ├── report/              # HTML report (index.html)
        │   └── index.html
        └── test-results/        # Per-test artifacts
            ├── auth-login/
            │   ├── screenshot.png    # Captured on failure
            │   ├── trace.zip         # Recorded trace
            │   └── video.webm        # Recorded video
            └── dashboard-view/
                └── screenshot.png
```

## VISUAL_PROOF.md Entry Format (MANDATORY)

After EVERY test run, append an entry with this format:

```markdown
## Run: {ISO-8601 datetime}

**Plan:** {phase}-{plan} (or "manual run")
**Commands:**
- `npm test` — {pass/fail}
- `npx playwright test` — {pass/fail}

**Result:** {PASS|FAIL} ({passed}/{total} tests)

### Test Summary
| Test | Status | Duration |
|------|--------|----------|
| auth.spec.ts | PASS | 2.3s |
| dashboard.spec.ts | FAIL | 3.1s |

### Console Errors
{List any console errors observed, or "None"}

### Artifact Paths
- Report: `.planning/artifacts/playwright/report/index.html`
- Failures: `.planning/artifacts/playwright/test-results/`

---
```

## UX Telemetry

Visual proof captures:
- Console errors (`console.error`)
- Page errors (uncaught exceptions)
- Network failures (4xx/5xx responses)
- Slow requests (>3s)

**Visual proof failure does NOT block phase completion** — logged as warning only.
However, failures MUST be recorded in VISUAL_PROOF.md for tracking.

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
