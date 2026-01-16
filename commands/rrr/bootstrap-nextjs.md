---
name: rrr:bootstrap-nextjs
description: Scaffold a Next.js App Router MVP with TypeScript, Tailwind, shadcn/ui, Vitest, and Playwright
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - TodoWrite
---

<objective>

Bootstrap a complete Next.js App Router project with Projecta's default MVP stack:

- **Framework:** Next.js (App Router) + TypeScript
- **Package Manager:** npm only
- **UI:** Tailwind CSS + shadcn/ui
- **Unit Tests:** Vitest + Testing Library
- **E2E Tests:** Playwright
- **Environment:** .env.example with common MVP placeholders

This command creates a production-ready foundation in ~5 minutes. Run once per project.

**After this command:** Run `/rrr:new-project` to define requirements and roadmap.

</objective>

<process>

## Phase 1: Pre-flight Checks

**MANDATORY FIRST STEP — Execute these checks before ANY scaffolding:**

1. **Check for existing project:**
   ```bash
   if [ -f package.json ]; then
     echo "ERROR: package.json already exists. This command is for new projects only."
     exit 1
   fi
   ```

2. **Check npm is available:**
   ```bash
   npm --version || { echo "ERROR: npm not found"; exit 1; }
   ```

3. **Initialize git repo if needed:**
   ```bash
   if [ -d .git ] || [ -f .git ]; then
     echo "Git repo exists"
   else
     git init
     echo "Initialized new git repo"
   fi
   ```

## Phase 2: Create Next.js Project

Display stage banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► BOOTSTRAPPING NEXT.JS MVP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

1. **Create Next.js app with App Router:**
   ```bash
   npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm --no-turbopack
   ```

   This creates:
   - TypeScript configuration
   - Tailwind CSS setup
   - ESLint configuration
   - App Router (src/app/)
   - Path alias @/*

2. **Verify creation:**
   ```bash
   [ -f package.json ] && [ -d src/app ] && echo "Next.js created successfully"
   ```

## Phase 3: Install shadcn/ui

1. **Initialize shadcn/ui:**
   ```bash
   npx shadcn@latest init -d
   ```

   This uses defaults:
   - Style: New York
   - Base color: Neutral
   - CSS variables: Yes

2. **Add Button component:**
   ```bash
   npx shadcn@latest add button -y
   ```

3. **Update homepage to show Button:**

   Edit `src/app/page.tsx` to include a simple demo:

   ```tsx
   import { Button } from "@/components/ui/button";

   export default function Home() {
     return (
       <main className="flex min-h-screen flex-col items-center justify-center p-24">
         <div className="text-center space-y-6">
           <h1 className="text-4xl font-bold">Welcome to Your MVP</h1>
           <p className="text-muted-foreground">
             Built with Next.js, TypeScript, Tailwind, and shadcn/ui
           </p>
           <Button size="lg">Get Started</Button>
         </div>
       </main>
     );
   }
   ```

## Phase 4: Setup Vitest + Testing Library

1. **Install Vitest and Testing Library:**
   ```bash
   npm install -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event
   ```

2. **Create vitest.config.ts:**

   Write to `vitest.config.ts`:
   ```typescript
   import { defineConfig } from 'vitest/config'
   import react from '@vitejs/plugin-react'
   import path from 'path'

   export default defineConfig({
     plugins: [react()],
     test: {
       environment: 'jsdom',
       setupFiles: ['./src/test/setup.ts'],
       include: ['src/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'],
     },
     resolve: {
       alias: {
         '@': path.resolve(__dirname, './src'),
       },
     },
   })
   ```

3. **Create test setup file:**

   Create `src/test/setup.ts`:
   ```typescript
   import '@testing-library/jest-dom'
   ```

4. **Create smoke unit test:**

   Create `src/app/page.test.tsx`:
   ```tsx
   import { render, screen } from '@testing-library/react'
   import { describe, it, expect } from 'vitest'
   import Home from './page'

   describe('Home', () => {
     it('renders the welcome heading', () => {
       render(<Home />)
       expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Welcome to Your MVP')
     })

     it('renders the get started button', () => {
       render(<Home />)
       expect(screen.getByRole('button', { name: /get started/i })).toBeInTheDocument()
     })
   })
   ```

5. **Add test script to package.json:**

   Edit `package.json` to add:
   ```json
   "scripts": {
     "test": "vitest run",
     "test:watch": "vitest"
   }
   ```

## Phase 5: Setup Playwright

1. **Install Playwright:**
   ```bash
   npm install -D @playwright/test
   npx playwright install chromium
   ```

2. **Create playwright.config.ts:**

   Write to `playwright.config.ts`:
   ```typescript
   import { defineConfig, devices } from '@playwright/test'

   export default defineConfig({
     testDir: './e2e',
     fullyParallel: true,
     forbidOnly: !!process.env.CI,
     retries: process.env.CI ? 2 : 0,
     workers: process.env.CI ? 1 : undefined,
     reporter: 'html',
     use: {
       baseURL: 'http://localhost:3000',
       trace: 'on-first-retry',
     },
     projects: [
       {
         name: 'chromium',
         use: { ...devices['Desktop Chrome'] },
       },
     ],
     webServer: {
       command: 'npm run dev',
       url: 'http://localhost:3000',
       reuseExistingServer: !process.env.CI,
     },
   })
   ```

3. **Create smoke e2e test:**

   Create `e2e/home.spec.ts`:
   ```typescript
   import { test, expect } from '@playwright/test'

   test.describe('Homepage', () => {
     test('should display welcome message and button', async ({ page }) => {
       await page.goto('/')

       // Check heading
       await expect(page.getByRole('heading', { level: 1 })).toContainText('Welcome to Your MVP')

       // Check button exists and is clickable
       const button = page.getByRole('button', { name: /get started/i })
       await expect(button).toBeVisible()
     })
   })
   ```

4. **Add e2e script to package.json:**

   Edit `package.json` to add:
   ```json
   "scripts": {
     "e2e": "playwright test",
     "e2e:ui": "playwright test --ui"
   }
   ```

## Phase 6: Create Environment Template

Create `.env.example` with common MVP placeholders:

```bash
# Database (Neon)
DATABASE_URL=

# Authentication (Clerk)
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=
CLERK_SECRET_KEY=

# Payments (Stripe)
STRIPE_SECRET_KEY=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
STRIPE_WEBHOOK_SECRET=

# Browser Automation (Browserbase)
BROWSERBASE_API_KEY=
BROWSERBASE_PROJECT_ID=

# Voice/Speech (Deepgram)
DEEPGRAM_API_KEY=

# App Config
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

Update `.gitignore` to ensure `.env` is ignored (should already be from create-next-app, but verify):
```bash
grep -q "^\.env" .gitignore || echo ".env*.local" >> .gitignore
```

## Phase 7: Verification

Display verification banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► VERIFYING SETUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

1. **Run unit tests:**
   ```bash
   npm test
   ```

   Expected: All tests pass (2 tests)

2. **Run e2e tests:**
   ```bash
   npm run e2e
   ```

   Expected: All tests pass (1 test)

3. **Verify dev server starts:**
   ```bash
   # Start dev server in background
   npm run dev &
   DEV_PID=$!

   # Wait for server to be ready
   sleep 5

   # Check if server responds
   curl -s http://localhost:3000 > /dev/null && echo "Dev server started successfully"

   # Kill dev server
   kill $DEV_PID 2>/dev/null
   ```

**If any verification fails:** Stop and fix the issue before proceeding.

## Phase 8: Commit Bootstrap

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore: bootstrap nextjs mvp

Stack:
- Next.js 15 (App Router) + TypeScript
- Tailwind CSS + shadcn/ui
- Vitest + Testing Library (unit)
- Playwright (e2e)

Includes:
- Button component on homepage
- Smoke unit test (2 assertions)
- Smoke e2e test (1 spec)
- .env.example with MVP placeholders
EOF
)"
```

## Phase 9: Done

Present completion:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► BOOTSTRAP COMPLETE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Next.js MVP scaffolded successfully**

| Component | Status |
|-----------|--------|
| Next.js App Router | ✓ |
| TypeScript | ✓ |
| Tailwind CSS | ✓ |
| shadcn/ui | ✓ |
| Vitest + Testing Library | ✓ |
| Playwright | ✓ |
| .env.example | ✓ |

**Commands:**
  npm run dev        Start dev server
  npm test           Run unit tests
  npm run e2e        Run e2e tests

───────────────────────────────────────────────────────────────

## ▶ Next Up

Define your project requirements and create a roadmap:

`/rrr:new-project`

───────────────────────────────────────────────────────────────
```

</process>

<output>

Files created:
- `package.json` (with all dependencies)
- `src/app/page.tsx` (homepage with Button)
- `src/components/ui/button.tsx` (shadcn/ui Button)
- `vitest.config.ts`
- `src/test/setup.ts`
- `src/app/page.test.tsx` (smoke unit test)
- `playwright.config.ts`
- `e2e/home.spec.ts` (smoke e2e test)
- `.env.example`

</output>

<success_criteria>

- [ ] package.json exists with correct dependencies
- [ ] Next.js App Router structure created (src/app/)
- [ ] TypeScript configured (tsconfig.json)
- [ ] Tailwind CSS configured (tailwind.config.ts)
- [ ] shadcn/ui initialized with Button component
- [ ] Homepage shows Button component
- [ ] Vitest configured with Testing Library
- [ ] Smoke unit test passes (npm test)
- [ ] Playwright configured
- [ ] Smoke e2e test passes (npm run e2e)
- [ ] .env.example created with MVP placeholders
- [ ] Dev server starts successfully
- [ ] All files committed with message "chore: bootstrap nextjs mvp"

</success_criteria>

<anti_patterns>

- Do NOT use yarn or pnpm — npm only
- Do NOT use Pages Router — App Router only
- Do NOT add unnecessary dependencies
- Do NOT skip verification steps
- Do NOT commit if tests fail
- Do NOT create .env with real credentials

</anti_patterns>
