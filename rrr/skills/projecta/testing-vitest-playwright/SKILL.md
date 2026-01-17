---
name: projecta.testing
description: Testing conventions using Vitest and Playwright
tags: [testing, vitest, playwright, unit, e2e]
max_lines: 120
---

# Testing Conventions

## When to Use

Load this skill when working on:
- Unit tests or test files
- E2E tests or integration tests
- Test configuration or setup
- Any task mentioning "test", "vitest", "playwright", or "e2e"

## Rules

### Unit Testing: Vitest

**MUST:**
- Use Vitest for all unit tests (NEVER Jest)
- Place unit tests in `__tests__/` directories or as `*.test.ts` files
- Use `describe`, `it`, `expect` from vitest
- Mock external dependencies using `vi.mock()`
- Run tests with `npm test` or `npm run test:watch`

**MUST NOT:**
- Install or use Jest
- Use Jest-specific APIs (`jest.fn()`, `jest.mock()`)
- Skip tests without explanation

### E2E Testing: Playwright

**MUST:**
- Use Playwright for all E2E tests (NEVER Cypress)
- Place E2E tests in `e2e/` directory
- Name test files as `*.spec.ts`
- Use Page Object Model for complex flows
- Run with `npm run e2e`

**MUST NOT:**
- Install or use Cypress
- Use Puppeteer for E2E tests
- Write flaky tests (use proper waits)

### NPM Scripts

Ensure these scripts exist in `package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "e2e": "playwright test",
    "e2e:headed": "playwright test --headed",
    "e2e:ui": "playwright test --ui"
  }
}
```

## Commands

```bash
# Unit tests
npm test                    # Run all unit tests
npm run test:watch          # Watch mode

# E2E tests
npm run e2e                 # Run all E2E tests
npm run e2e:headed          # Run with browser visible
npm run e2e:ui              # Open Playwright UI
npx playwright show-report  # View HTML report

# Generate tests
npx playwright codegen localhost:3000  # Record interactions
```

## Environment Variables

```bash
# Playwright
PLAYWRIGHT_BASE_URL=http://localhost:3000
CI=true  # Headless mode in CI
```

## Artifacts

Test artifacts stored at:
- Unit test coverage: `coverage/`
- Playwright report: `playwright-report/`
- Playwright screenshots: `test-results/`

## Definition of Done

MVP is complete when:
1. `npm test` passes (unit tests)
2. `npm run e2e` passes (E2E tests)
3. Local demo runs without errors
