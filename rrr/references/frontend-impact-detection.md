# Frontend Impact Detection

Shared detection rules for determining if a plan affects the frontend.

## Classification

### FRONTEND_IMPACTING (requires full verification ladder)

A plan is **frontend-impacting** if ANY of these conditions are true:

#### 1. File Path Patterns

`files_modified` matches ANY of:
- `src/app/**` or `app/**` (Next.js pages/layouts)
- `src/components/**` or `components/**`
- `src/pages/**` or `pages/**`
- `ui/**` or `src/ui/**`
- `layouts/**` or `src/layouts/**`
- `styles/**` or `src/styles/**`
- `public/**`
- Any `*.tsx` or `*.jsx` file
- Any `*.css`, `*.scss`, `*.sass` file
- `tailwind.config.*`

#### 2. UI/UX Keywords

Objective, task names, or descriptions mention:
- **UI terms:** `ui`, `ux`, `form`, `modal`, `dialog`, `button`, `input`, `layout`
- **Flow terms:** `flow`, `wizard`, `stepper`, `navigation`, `menu`, `sidebar`
- **Visual terms:** `preview`, `editor`, `dashboard`, `chart`, `graph`, `animation`
- **Page terms:** `page`, `screen`, `view`, `component`, `header`, `footer`
- **Design terms:** `responsive`, `mobile`, `tablet`, `desktop`, `breakpoint`
- **Interaction terms:** `hover`, `click`, `drag`, `drop`, `scroll`, `tooltip`

#### 3. API Routes Used by Frontend

- `src/app/api/**` routes that serve UI data
- `pages/api/**` routes called from frontend
- Plan mentions: "API consumed by UI", "frontend fetches", "client calls"

#### 4. Frontend Integration Signals

Plan mentions ANY of:
- "frontend", "client-side", "browser", "user-facing"
- "render", "display", "show", "visible"
- "integration", "wiring", "connect frontend", "hook up"
- "end-to-end", "e2e", "full stack"

#### 5. Schema/Contract Changes Affecting UI

- Types/DTOs used in components
- Zod schemas for forms
- API response types rendered in UI
- Auth/session flow changes
- CORS, cookies, redirects
- Webhooks displayed in UI

### BACKEND_ONLY (unit tests only)

A plan is **backend-only** if ALL of these are true:

1. **Only touches backend paths:**
   - `src/lib/**` (pure utilities)
   - `src/server/**` (server-only code)
   - `scripts/**` (CLI/build scripts)
   - `*.config.*` (configuration)
   - Database migrations, seeds
   - `src/jobs/**`, `src/workers/**`, `src/cron/**`

2. **No UI/UX keywords present**

3. **Explicit backend indicators:**
   - "migration", "seed", "script", "cli", "cron", "job"
   - "background worker", "queue", "batch"
   - "internal tooling", "admin script"
   - "refactor internals", "optimize query", "add logging"

## Decision Tree

```
START
  │
  ├─ Does files_modified contain ANY .tsx/.jsx file?
  │   └─ YES → FRONTEND_IMPACTING
  │
  ├─ Does files_modified contain src/app/**, src/components/**, src/pages/**?
  │   └─ YES → FRONTEND_IMPACTING
  │
  ├─ Does objective/tasks mention UI keywords?
  │   └─ YES → FRONTEND_IMPACTING
  │
  ├─ Is this an API route? Check if called from UI
  │   └─ YES (serves UI) → FRONTEND_IMPACTING
  │   └─ NO (internal only) → Continue
  │
  ├─ Does plan mention "frontend", "client", "browser", "integration"?
  │   └─ YES → FRONTEND_IMPACTING
  │
  └─ DEFAULT → BACKEND_ONLY
```

## Verification Requirements by Classification

### FRONTEND_IMPACTING Plans

```yaml
verification:
  surface: ui_affecting
  frontend_impact: true
  required_steps:
    - unit_tests
    - playwright
    - chrome_visual_check
```

**Mandatory two-step visual verification:**
1. **Playwright (automated):** Headless E2E tests
2. **Chrome visual check (automated interactive):** `claude --chrome` verification loop

### BACKEND_ONLY Plans

```yaml
verification:
  surface: backend_only
  frontend_impact: false
  required_steps:
    - unit_tests
```

No visual verification required.

## Artifact Paths

All verification artifacts stored in `.planning/artifacts/`:

```
.planning/
├── VISUAL_PROOF.md              # Append-only verification log
└── artifacts/
    ├── playwright/
    │   ├── report/              # HTML report
    │   └── test-results/        # Screenshots, traces, videos
    └── chrome/
        ├── screenshots/         # Chrome visual check captures
        └── logs/                # Console/network logs
```
