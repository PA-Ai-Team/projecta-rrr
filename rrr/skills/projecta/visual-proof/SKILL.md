---
name: projecta.visual-proof
description: Visual proof system for capturing UI verification artifacts
tags: [testing, playwright, artifacts, screenshots, visual]
max_lines: 100
---

# Visual Proof System

## When to Use

Load this skill when:
- Verifying UI changes visually
- Running post-execution validation
- Capturing screenshots or traces for review
- Any task mentioning "visual", "screenshot", or "proof"

## Rules

### Artifact Storage

**MUST:**
- Store all artifacts in `.planning/artifacts/playwright/`
- Log results to `.planning/VISUAL_PROOF.md` (append-only)
- Capture screenshots on test failure
- Enable trace recording for debugging

**MUST NOT:**
- Delete existing VISUAL_PROOF.md entries
- Store artifacts outside `.planning/artifacts/`
- Skip visual proof after phase execution

### Running Visual Proof

After phase execution completes:

1. Check for `e2e/*.spec.ts` files
2. Run `bash scripts/visual-proof.sh`
3. Results logged to `.planning/VISUAL_PROOF.md`
4. Artifacts in `.planning/artifacts/playwright/`

## Commands

```bash
# Run visual proof
bash scripts/visual-proof.sh

# Or via npm script
npm run visual:proof

# Open HTML report
npm run visual:open
# or
npx playwright show-report .planning/artifacts/playwright/report
```

## Environment Variables

```bash
# Visual proof configuration
VISUAL_PROOF_MODE=playwright     # playwright | playwright_headed | hybrid
PLAYWRIGHT_OUTPUT_DIR=.planning/artifacts/playwright
```

## Artifacts

```
.planning/
├── VISUAL_PROOF.md              # Append-only run log
└── artifacts/
    └── playwright/
        ├── report/              # HTML report
        └── test-results/        # Screenshots, traces, videos
            ├── screenshot-1.png
            ├── trace.zip
            └── video.webm
```

## VISUAL_PROOF.md Format

Each run appends an entry:

```markdown
## Run: 2026-01-17T10:30:00Z

**Phase:** 04-auth
**Mode:** playwright
**Result:** PASS (5/5 tests)

### Tests
| Test | Status | Duration |
|------|--------|----------|
| login.spec.ts | PASS | 2.3s |
| register.spec.ts | PASS | 3.1s |

### Telemetry
- Console errors: 0
- Page errors: 0
- Network failures: 0

### Artifacts
- Report: `.planning/artifacts/playwright/report/index.html`
```

## UX Telemetry

Visual proof captures:
- Console errors (`console.error`)
- Page errors (uncaught exceptions)
- Network failures (4xx/5xx responses)
- Slow requests (>3s)

**Visual proof failure does NOT block phase completion** — logged as warning only.
