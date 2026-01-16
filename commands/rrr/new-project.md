---
name: rrr:new-project
description: Initialize a new project with deep context gathering and PROJECT.md
allowed-tools:
  - Read
  - Bash
  - Write
  - Task
  - AskUserQuestion
---

<objective>

Initialize a new project through unified flow: questioning → research (optional) → requirements → roadmap.

This is the most leveraged moment in any project. Deep questioning here means better plans, better execution, better outcomes. One command takes you from idea to ready-for-planning.

## Projecta Preferred Pack

**Source of Truth:** `projecta.defaults.json` at repo root.

**Core Stack (always assumed):**
- Framework: Next.js (App Router)
- Language: TypeScript
- Package Manager: npm only
- UI: Tailwind CSS + shadcn/ui
- Unit Tests: Vitest + Testing Library
- E2E Tests: Playwright

**Preferred Providers (defaults, overrideable with reason):**
- Database: Neon
- Auth: Clerk (default), Neon Auth (alternative)
- Payments: Stripe
- Object Storage: Cloudflare R2
- Analytics: PostHog
- Voice: Deepgram
- Deploy: Render

**Agent Stack (when agents needed):**
- Orchestration: Mastra
- Agent Auth: Auth.dev
- Agent Mail: Agentmail
- Sandbox: E2B
- Browser Automation: Browserbase

**Discouraged (allowed with explicit reason):**
- Firebase, Supabase, Auth0, Vercel, PlanetScale

**Override Rules:**
- Defaults are recommended, NOT mandatory.
- If user wants to override any default, they must explicitly say so and provide a reason.
- All overrides are recorded in "Deviation Notes" section of PROJECT.md.

**Greenfield vs Brownfield:**
- GREENFIELD (empty folder): Runs `/rrr:bootstrap-nextjs` logic first, then questionnaire.
- BROWNFIELD (existing code): Skips bootstrap entirely, only creates `.planning/` artifacts. Does NOT run create-next-app, does NOT overwrite files.

**Creates:**
- `.planning/PROJECT.md` — project context (includes Deviation Notes)
- `.planning/MVP_FEATURES.yml` — capability selections per project
- `.planning/config.json` — workflow preferences
- `.planning/research/` — domain research (optional)
- `.planning/REQUIREMENTS.md` — scoped requirements
- `.planning/ROADMAP.md` — phase structure
- `.planning/STATE.md` — project memory
- `.planning/phases/` — phase directories

**After this command:** Run `/rrr:plan-phase 1` to start execution.

</objective>

<execution_context>

@./.claude/rrr/references/questioning.md
@./.claude/rrr/references/ui-brand.md
@./.claude/rrr/templates/project.md
@./.claude/rrr/templates/requirements.md

</execution_context>

<process>

## Preflight: Greenfield vs Brownfield Safety

**MANDATORY FIRST STEP — Run these checks before ANY user interaction or modification:**

Display initial banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► NEW PROJECT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 1: Preflight Shell Checks

Run these commands to detect repo state (use Bash tool):

```bash
# Preflight detection
echo "=== PREFLIGHT CHECK ==="

# Check for existing files/dirs
ls -la 2>/dev/null | head -20

# Check package.json
test -f package.json && echo "HAS_PACKAGE_JSON=yes" && cat package.json | head -10 || echo "HAS_PACKAGE_JSON=no"

# Check app directories
test -d app && echo "HAS_APP_DIR=yes" && ls app | head -5 || echo "HAS_APP_DIR=no"
test -d src && echo "HAS_SRC_DIR=yes" && ls src | head -5 || echo "HAS_SRC_DIR=no"

# Check next.config
ls next.config.* 2>/dev/null && echo "HAS_NEXT_CONFIG=yes" || echo "HAS_NEXT_CONFIG=no"

# Check git state
git rev-parse --is-inside-work-tree 2>/dev/null && git log -1 --oneline 2>/dev/null && echo "HAS_GIT_COMMITS=yes" || echo "HAS_GIT_COMMITS=no"

# Check RRR state
test -f .planning/STATE.md && echo "HAS_RRR_STATE=yes" || echo "HAS_RRR_STATE=no"
test -f .planning/PROJECT.md && echo "HAS_RRR_PROJECT=yes" || echo "HAS_RRR_PROJECT=no"

echo "=== END PREFLIGHT ==="
```

### Step 2: Classify Repo Mode

Based on preflight results, classify as:

**BROWNFIELD** if ANY of these are true:
- `HAS_PACKAGE_JSON=yes`
- `HAS_APP_DIR=yes`
- `HAS_SRC_DIR=yes`
- `HAS_NEXT_CONFIG=yes`
- `HAS_GIT_COMMITS=yes`
- `HAS_RRR_STATE=yes`

**GREENFIELD** if ALL are false (empty directory).

### Step 3: Handle Based on Mode

**If `HAS_RRR_STATE=yes` (RRR already initialized):**

Display and EXIT:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR project already initialized
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This repo has .planning/STATE.md — RRR is already set up.

To resume work: /rrr:progress
To check status: /rrr:resume-work
```

Stop here. Do NOT proceed.

---

**If `HAS_RRR_PROJECT=yes` but `HAS_RRR_STATE=no`:**

Project was partially initialized. Continue to Phase 1 to complete setup.

---

**If BROWNFIELD (existing code, no RRR):**

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BROWNFIELD MODE — Existing repo detected
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Detected existing code. RRR will:
✓ Add .planning/ directory for project management
✓ Keep all existing files untouched
✗ Skip bootstrap (no create-next-app, no restructuring)

Starting RRR questionnaire...
```

**BROWNFIELD RULES:**
- Do NOT run `create-next-app`
- Do NOT overwrite or restructure existing files
- Do NOT reinstall Tailwind/shadcn/Vitest/Playwright
- ONLY create `.planning/` artifacts
- Proceed directly to Phase 1 (Setup)

Continue to Phase 1.

---

**If GREENFIELD (empty directory):**

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GREENFIELD MODE — Empty directory
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Bootstrapping with Projecta defaults...
(Next.js + TypeScript + Tailwind + shadcn/ui + Vitest + Playwright)
```

Run `/rrr:bootstrap-nextjs` logic:

a. **Initialize git:**
   ```bash
   git init
   ```

b. **Create Next.js app:**
   ```bash
   npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm --no-turbopack
   ```

c. **Initialize shadcn/ui and add Button:**
   ```bash
   npx shadcn@latest init -d
   npx shadcn@latest add button -y
   ```

d. **Update homepage** — Edit `src/app/page.tsx`:
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

e. **Install Vitest + Testing Library:**
   ```bash
   npm install -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event
   ```

f. **Create vitest.config.ts** and **src/test/setup.ts** and **src/app/page.test.tsx** (see `/rrr:bootstrap-nextjs` for full content)

g. **Add test scripts to package.json:** `"test": "vitest run"`, `"test:watch": "vitest"`

h. **Install Playwright:**
   ```bash
   npm install -D @playwright/test
   npx playwright install chromium
   ```

i. **Create playwright.config.ts** and **e2e/home.spec.ts** (see `/rrr:bootstrap-nextjs` for full content)

j. **Add e2e scripts to package.json:** `"e2e": "playwright test"`, `"e2e:ui": "playwright test --ui"`

k. **Create .env.example** with MVP placeholders

l. **Run tests:**
   ```bash
   npm test
   npm run e2e
   ```

m. **Commit bootstrap:**
   ```bash
   git add -A
   git commit -m "chore: bootstrap nextjs mvp"
   ```

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BOOTSTRAP COMPLETE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Starting RRR questionnaire...
```

Continue to Phase 1.

## Phase 1: Setup

**Execute these checks:**

1. **Initialize git repo in THIS directory** (required even if inside a parent repo):
   ```bash
   if [ -d .git ] || [ -f .git ]; then
       echo "Git repo exists in current directory"
   else
       git init
       echo "Initialized new git repo"
   fi
   ```

2. **Detect existing code (brownfield detection):**
   ```bash
   CODE_FILES=$(find . -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.swift" -o -name "*.java" 2>/dev/null | grep -v node_modules | grep -v .git | head -20)
   HAS_PACKAGE=$([ -f package.json ] || [ -f requirements.txt ] || [ -f Cargo.toml ] || [ -f go.mod ] || [ -f Package.swift ] && echo "yes")
   HAS_CODEBASE_MAP=$([ -d .planning/codebase ] && echo "yes")
   ```

   **You MUST run all bash commands above using the Bash tool before proceeding.**

## Phase 2: Brownfield Offer

**If existing code detected and .planning/codebase/ doesn't exist:**

Check the results from setup step:
- If `CODE_FILES` is non-empty OR `HAS_PACKAGE` is "yes"
- AND `HAS_CODEBASE_MAP` is NOT "yes"

Use AskUserQuestion:
- header: "Existing Code"
- question: "I detected existing code in this directory. Would you like to map the codebase first?"
- options:
  - "Map codebase first" — Run /rrr:map-codebase to understand existing architecture (Recommended)
  - "Skip mapping" — Proceed with project initialization

**If "Map codebase first":**
```
Run `/rrr:map-codebase` first, then return to `/rrr:new-project`
```
Exit command.

**If "Skip mapping":** Continue to Phase 3.

**If no existing code detected OR codebase already mapped:** Continue to Phase 2.5.

## Phase 2.5: Capability Selection (MVP_FEATURES.yml)

**This phase generates `.planning/MVP_FEATURES.yml` based on capability needs.**

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► CAPABILITY SELECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Using Projecta Preferred Pack defaults.
Overrides allowed with explicit reason.
```

### Step 1: Preset Quick-Start (Optional)

Use AskUserQuestion:
- header: "Preset"
- question: "Start with a use-case preset? This pre-configures capabilities."
- options:
  - "landing-waitlist" — Landing page + email capture (no auth, no db)
  - "saas-dashboard" — SaaS with Clerk + Neon + optional Stripe
  - "api-admin" — API backend + admin panel (Neon, optional auth)
  - "voice-agent" — Voice AI agent (Deepgram + full agent stack)
  - "None" — Configure capabilities manually (Recommended for custom)

**If preset selected:** Load preset defaults, skip to Step 3 (confirm/override).

**If "None":** Continue to Step 2.

### Step 2: Capability Questionnaire

Ask these questions using AskUserQuestion (can batch into 2-3 calls):

**Authentication:**
- header: "Auth"
- question: "Is user login needed?"
- options:
  - "Yes, use Clerk (Recommended)" — Clerk for auth
  - "Yes, use Neon Auth" — Neon's built-in auth
  - "Yes, other" — Specify provider (requires reason)
  - "No auth needed" — Skip authentication

**Database:**
- header: "Database"
- question: "Is a database needed?"
- options:
  - "Yes, use Neon (Recommended)" — Neon PostgreSQL
  - "Yes, other" — Specify provider (requires reason)
  - "No database needed" — Skip database

**Payments:**
- header: "Payments"
- question: "Are payments needed?"
- options:
  - "Yes, use Stripe (Recommended)" — Stripe for payments
  - "Yes, other" — Specify provider (requires reason)
  - "No payments needed" — Skip payments

**Storage & Analytics:**
- header: "Storage"
- question: "Are file uploads/media needed?"
- options:
  - "Yes, use R2 (Recommended)" — Cloudflare R2
  - "Yes, other" — Specify provider (requires reason)
  - "No storage needed" — Skip object storage

- header: "Analytics"
- question: "Is analytics needed?"
- options:
  - "Yes, use PostHog (Recommended)" — PostHog analytics
  - "Yes, other" — Specify provider (requires reason)
  - "No analytics needed" — Skip analytics

**Voice:**
- header: "Voice"
- question: "Is voice/speech needed?"
- options:
  - "Yes, use Deepgram (Recommended)" — Deepgram STT/TTS
  - "Yes, other" — Specify provider (requires reason)
  - "No voice needed" — Skip voice

**Agents:**
- header: "Agents"
- question: "Are AI agents needed?"
- options:
  - "Yes, full agent stack (Recommended)" — Mastra + Auth.dev + Agentmail + E2B + Browserbase
  - "Yes, minimal" — Just Mastra orchestration
  - "Yes, custom" — Specify stack (requires reason)
  - "No agents needed" — Skip agent stack

**Deployment:**
- header: "Deploy"
- question: "Deploy target?"
- options:
  - "Render (Recommended)" — Deploy to Render
  - "Other" — Specify platform (requires reason)
  - "Not yet" — Skip deployment setup

### Step 3: Collect Override Reasons

**If user selected "other" for any capability OR selected a discouraged provider:**

Ask inline: "You chose [provider] instead of the default [default]. What's the reason for this choice?"

Record each override with:
- capability: what changed
- default: Preferred Pack value
- chosen: user's choice
- reason: user's explanation

### Step 4: Generate MVP_FEATURES.yml

Write `.planning/MVP_FEATURES.yml`:

```yaml
# Generated by /rrr:new-project
# Source: Projecta Preferred Pack with user selections

features:
  auth: [clerk | neon-auth | none | other]
  db: [neon | none | other]
  deploy: [render | none | other]
  payments: [stripe | none | other]
  object_storage: [r2 | none | other]
  analytics: [posthog | none | other]
  voice: [deepgram | none | other]

agent_stack:
  enabled: [true | false]
  orchestration: [mastra | none | other]
  agent_auth: [authdev | none | other]
  agent_mail: [agentmail | none | other]
  sandbox: [e2b | none | other]
  browser_automation: [browserbase | none | other]

# Deviation Notes (if any overrides from Preferred Pack)
deviations:
  # - capability: auth
  #   default: clerk
  #   chosen: auth0
  #   reason: "Client requires Auth0 for SSO compliance"
```

### Step 5: Display Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 MVP FEATURES CONFIGURED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Features:
  Auth: [value]
  Database: [value]
  Payments: [value]
  Storage: [value]
  Analytics: [value]
  Voice: [value]

Agent Stack: [enabled/disabled]
  [if enabled, list components]

Deviations: [count or "None"]

File: .planning/MVP_FEATURES.yml
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Continue to Phase 3.

## Phase 3: Deep Questioning

**Display stage banner:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► QUESTIONING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Open the conversation:**

Ask inline (freeform, NOT AskUserQuestion):

"What do you want to build?"

Wait for their response. This gives you the context needed to ask intelligent follow-up questions.

**Follow the thread:**

Based on what they said, ask follow-up questions that dig into their response. Use AskUserQuestion with options that probe what they mentioned — interpretations, clarifications, concrete examples.

Keep following threads. Each answer opens new threads to explore. Ask about:
- What excited them
- What problem sparked this
- What they mean by vague terms
- What it would actually look like
- What's already decided

Consult `questioning.md` for techniques:
- Challenge vagueness
- Make abstract concrete
- Surface assumptions
- Find edges
- Reveal motivation

**Check context (background, not out loud):**

As you go, mentally check the context checklist from `questioning.md`. If gaps remain, weave questions naturally. Don't suddenly switch to checklist mode.

**Decision gate:**

When you could write a clear PROJECT.md, use AskUserQuestion:

- header: "Ready?"
- question: "I think I understand what you're after. Ready to create PROJECT.md?"
- options:
  - "Create PROJECT.md" — Let's move forward
  - "Keep exploring" — I want to share more / ask me more

If "Keep exploring" — ask what they want to add, or identify gaps and probe naturally.

Loop until "Create PROJECT.md" selected.

## Phase 4: Write PROJECT.md

Synthesize all context into `.planning/PROJECT.md` using the template from `templates/project.md`.

**For greenfield projects:**

Initialize requirements as hypotheses:

```markdown
## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] [Requirement 1]
- [ ] [Requirement 2]
- [ ] [Requirement 3]

### Out of Scope

- [Exclusion 1] — [why]
- [Exclusion 2] — [why]
```

All Active requirements are hypotheses until shipped and validated.

**For brownfield projects (codebase map exists):**

Infer Validated requirements from existing code:

1. Read `.planning/codebase/ARCHITECTURE.md` and `STACK.md`
2. Identify what the codebase already does
3. These become the initial Validated set

```markdown
## Requirements

### Validated

- ✓ [Existing capability 1] — existing
- ✓ [Existing capability 2] — existing
- ✓ [Existing capability 3] — existing

### Active

- [ ] [New requirement 1]
- [ ] [New requirement 2]

### Out of Scope

- [Exclusion 1] — [why]
```

**Key Decisions:**

Initialize with any decisions made during questioning:

```markdown
## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| [Choice from questioning] | [Why] | — Pending |
```

**Deviation Notes (from Preferred Pack):**

Include any overrides from the capability selection phase:

```markdown
## Deviation Notes

Overrides from Projecta Preferred Pack (`projecta.defaults.json`):

| Capability | Default | Chosen | Reason |
|------------|---------|--------|--------|
| [capability] | [preferred pack default] | [user's choice] | [user's reason] |

_If no deviations: "None — using all Preferred Pack defaults."_
```

Read deviations from `.planning/MVP_FEATURES.yml` deviations section and format as table.

**Last updated footer:**

```markdown
---
*Last updated: [date] after initialization*
```

Do not compress. Capture everything gathered.

**Commit PROJECT.md:**

```bash
mkdir -p .planning
git add .planning/PROJECT.md
git commit -m "$(cat <<'EOF'
docs: initialize project

[One-liner from PROJECT.md What This Is section]
EOF
)"
```

## Phase 5: Workflow Preferences

Ask all workflow preferences in a single AskUserQuestion call (3 questions):

```
questions: [
  {
    header: "Mode",
    question: "How do you want to work?",
    multiSelect: false,
    options: [
      { label: "YOLO (Recommended)", description: "Auto-approve, just execute" },
      { label: "Interactive", description: "Confirm at each step" }
    ]
  },
  {
    header: "Depth",
    question: "How thorough should planning be?",
    multiSelect: false,
    options: [
      { label: "Quick", description: "Ship fast (3-5 phases, 1-3 plans each)" },
      { label: "Standard", description: "Balanced scope and speed (5-8 phases, 3-5 plans each)" },
      { label: "Comprehensive", description: "Thorough coverage (8-12 phases, 5-10 plans each)" }
    ]
  },
  {
    header: "Execution",
    question: "Run plans in parallel?",
    multiSelect: false,
    options: [
      { label: "Parallel (Recommended)", description: "Independent plans run simultaneously" },
      { label: "Sequential", description: "One plan at a time" }
    ]
  }
]
```

Create `.planning/config.json` with chosen mode, depth, and parallelization.

**Commit config.json:**

```bash
git add .planning/config.json
git commit -m "$(cat <<'EOF'
chore: add project config

Mode: [chosen mode]
Depth: [chosen depth]
Parallelization: [enabled/disabled]
EOF
)"
```

## Phase 6: Research Decision

Use AskUserQuestion:
- header: "Research"
- question: "Research the domain ecosystem before defining requirements?"
- options:
  - "Research first (Recommended)" — Discover standard stacks, expected features, architecture patterns
  - "Skip research" — I know this domain well, go straight to requirements

**If "Research first":**

Display stage banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► RESEARCHING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Researching [domain] ecosystem...
```

Create research directory:
```bash
mkdir -p .planning/research
```

**Determine milestone context:**

Check if this is greenfield or subsequent milestone:
- If no "Validated" requirements in PROJECT.md → Greenfield (building from scratch)
- If "Validated" requirements exist → Subsequent milestone (adding to existing app)

Display spawning indicator:
```
◆ Spawning 4 researchers in parallel...
  → Stack research
  → Features research
  → Architecture research
  → Pitfalls research
```

Spawn 4 parallel rrr-project-researcher agents with rich context:

```
Task(prompt="
<research_type>
Project Research — Stack dimension for [domain].
</research_type>

<milestone_context>
[greenfield OR subsequent]

Greenfield: Research the standard stack for building [domain] from scratch.
Subsequent: Research what's needed to add [target features] to an existing [domain] app. Don't re-research the existing system.
</milestone_context>

<question>
What's the standard 2025 stack for [domain]?
</question>

<project_context>
[PROJECT.md summary - core value, constraints, what they're building]
</project_context>

<downstream_consumer>
Your STACK.md feeds into roadmap creation. Be prescriptive:
- Specific libraries with versions
- Clear rationale for each choice
- What NOT to use and why
</downstream_consumer>

<quality_gate>
- [ ] Versions are current (verify with Context7/official docs, not training data)
- [ ] Rationale explains WHY, not just WHAT
- [ ] Confidence levels assigned to each recommendation
</quality_gate>

<output>
Write to: .planning/research/STACK.md
Use template: ./.claude/rrr/templates/research-project/STACK.md
</output>
", subagent_type="rrr-project-researcher", description="Stack research")

Task(prompt="
<research_type>
Project Research — Features dimension for [domain].
</research_type>

<milestone_context>
[greenfield OR subsequent]

Greenfield: What features do [domain] products have? What's table stakes vs differentiating?
Subsequent: How do [target features] typically work? What's expected behavior?
</milestone_context>

<question>
What features do [domain] products have? What's table stakes vs differentiating?
</question>

<project_context>
[PROJECT.md summary]
</project_context>

<downstream_consumer>
Your FEATURES.md feeds into requirements definition. Categorize clearly:
- Table stakes (must have or users leave)
- Differentiators (competitive advantage)
- Anti-features (things to deliberately NOT build)
</downstream_consumer>

<quality_gate>
- [ ] Categories are clear (table stakes vs differentiators vs anti-features)
- [ ] Complexity noted for each feature
- [ ] Dependencies between features identified
</quality_gate>

<output>
Write to: .planning/research/FEATURES.md
Use template: ./.claude/rrr/templates/research-project/FEATURES.md
</output>
", subagent_type="rrr-project-researcher", description="Features research")

Task(prompt="
<research_type>
Project Research — Architecture dimension for [domain].
</research_type>

<milestone_context>
[greenfield OR subsequent]

Greenfield: How are [domain] systems typically structured? What are major components?
Subsequent: How do [target features] integrate with existing [domain] architecture?
</milestone_context>

<question>
How are [domain] systems typically structured? What are major components?
</question>

<project_context>
[PROJECT.md summary]
</project_context>

<downstream_consumer>
Your ARCHITECTURE.md informs phase structure in roadmap. Include:
- Component boundaries (what talks to what)
- Data flow (how information moves)
- Suggested build order (dependencies between components)
</downstream_consumer>

<quality_gate>
- [ ] Components clearly defined with boundaries
- [ ] Data flow direction explicit
- [ ] Build order implications noted
</quality_gate>

<output>
Write to: .planning/research/ARCHITECTURE.md
Use template: ./.claude/rrr/templates/research-project/ARCHITECTURE.md
</output>
", subagent_type="rrr-project-researcher", description="Architecture research")

Task(prompt="
<research_type>
Project Research — Pitfalls dimension for [domain].
</research_type>

<milestone_context>
[greenfield OR subsequent]

Greenfield: What do [domain] projects commonly get wrong? Critical mistakes?
Subsequent: What are common mistakes when adding [target features] to [domain]?
</milestone_context>

<question>
What do [domain] projects commonly get wrong? Critical mistakes?
</question>

<project_context>
[PROJECT.md summary]
</project_context>

<downstream_consumer>
Your PITFALLS.md prevents mistakes in roadmap/planning. For each pitfall:
- Warning signs (how to detect early)
- Prevention strategy (how to avoid)
- Which phase should address it
</downstream_consumer>

<quality_gate>
- [ ] Pitfalls are specific to this domain (not generic advice)
- [ ] Prevention strategies are actionable
- [ ] Phase mapping included where relevant
</quality_gate>

<output>
Write to: .planning/research/PITFALLS.md
Use template: ./.claude/rrr/templates/research-project/PITFALLS.md
</output>
", subagent_type="rrr-project-researcher", description="Pitfalls research")
```

After all 4 agents complete, spawn synthesizer to create SUMMARY.md:

```
Task(prompt="
<task>
Synthesize research outputs into SUMMARY.md.
</task>

<research_files>
Read these files:
- .planning/research/STACK.md
- .planning/research/FEATURES.md
- .planning/research/ARCHITECTURE.md
- .planning/research/PITFALLS.md
</research_files>

<output>
Write to: .planning/research/SUMMARY.md
Use template: ./.claude/rrr/templates/research-project/SUMMARY.md
Commit after writing.
</output>
", subagent_type="rrr-research-synthesizer", description="Synthesize research")
```

Display research complete banner and key findings:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► RESEARCH COMPLETE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Key Findings

**Stack:** [from SUMMARY.md]
**Table Stakes:** [from SUMMARY.md]
**Watch Out For:** [from SUMMARY.md]

Files: `.planning/research/`
```

**If "Skip research":** Continue to Phase 7.

## Phase 7: Define Requirements

Display stage banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► DEFINING REQUIREMENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Load context:**

Read PROJECT.md and extract:
- Core value (the ONE thing that must work)
- Stated constraints (budget, timeline, tech limitations)
- Any explicit scope boundaries

**If research exists:** Read research/FEATURES.md and extract feature categories.

**Present features by category:**

```
Here are the features for [domain]:

## Authentication
**Table stakes:**
- Sign up with email/password
- Email verification
- Password reset
- Session management

**Differentiators:**
- Magic link login
- OAuth (Google, GitHub)
- 2FA

**Research notes:** [any relevant notes]

---

## [Next Category]
...
```

**If no research:** Gather requirements through conversation instead.

Ask: "What are the main things users need to be able to do?"

For each capability mentioned:
- Ask clarifying questions to make it specific
- Probe for related capabilities
- Group into categories

**Scope each category:**

For each category, use AskUserQuestion:

- header: "[Category name]"
- question: "Which [category] features are in v1?"
- multiSelect: true
- options:
  - "[Feature 1]" — [brief description]
  - "[Feature 2]" — [brief description]
  - "[Feature 3]" — [brief description]
  - "None for v1" — Defer entire category

Track responses:
- Selected features → v1 requirements
- Unselected table stakes → v2 (users expect these)
- Unselected differentiators → out of scope

**Identify gaps:**

Use AskUserQuestion:
- header: "Additions"
- question: "Any requirements research missed? (Features specific to your vision)"
- options:
  - "No, research covered it" — Proceed
  - "Yes, let me add some" — Capture additions

**Validate core value:**

Cross-check requirements against Core Value from PROJECT.md. If gaps detected, surface them.

**Generate REQUIREMENTS.md:**

Create `.planning/REQUIREMENTS.md` with:
- v1 Requirements grouped by category (checkboxes, REQ-IDs)
- v2 Requirements (deferred)
- Out of Scope (explicit exclusions with reasoning)
- Traceability section (empty, filled by roadmap)

**REQ-ID format:** `[CATEGORY]-[NUMBER]` (AUTH-01, CONTENT-02)

**Requirement quality criteria:**

Good requirements are:
- **Specific and testable:** "User can reset password via email link" (not "Handle password reset")
- **User-centric:** "User can X" (not "System does Y")
- **Atomic:** One capability per requirement (not "User can login and manage profile")
- **Independent:** Minimal dependencies on other requirements

Reject vague requirements. Push for specificity:
- "Handle authentication" → "User can log in with email/password and stay logged in across sessions"
- "Support sharing" → "User can share post via link that opens in recipient's browser"

**Present full requirements list:**

Show every requirement (not counts) for user confirmation:

```
## v1 Requirements

### Authentication
- [ ] **AUTH-01**: User can create account with email/password
- [ ] **AUTH-02**: User can log in and stay logged in across sessions
- [ ] **AUTH-03**: User can log out from any page

### Content
- [ ] **CONT-01**: User can create posts with text
- [ ] **CONT-02**: User can edit their own posts

[... full list ...]

---

Does this capture what you're building? (yes / adjust)
```

If "adjust": Return to scoping.

**Commit requirements:**

```bash
git add .planning/REQUIREMENTS.md
git commit -m "$(cat <<'EOF'
docs: define v1 requirements

[X] requirements across [N] categories
[Y] requirements deferred to v2
EOF
)"
```

## Phase 8: Create Roadmap

Display stage banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► CREATING ROADMAP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

◆ Spawning roadmapper...
```

Spawn rrr-roadmapper agent with context:

```
Task(prompt="
<planning_context>

**Project:**
@.planning/PROJECT.md

**Requirements:**
@.planning/REQUIREMENTS.md

**Research (if exists):**
@.planning/research/SUMMARY.md

**Config:**
@.planning/config.json

</planning_context>

<instructions>
Create roadmap:
1. Derive phases from requirements (don't impose structure)
2. Map every v1 requirement to exactly one phase
3. Derive 2-5 success criteria per phase (observable user behaviors)
4. Validate 100% coverage
5. Write files immediately (ROADMAP.md, STATE.md, phase directories, update REQUIREMENTS.md traceability)
6. Return ROADMAP CREATED with summary

Write files first, then return. This ensures artifacts persist even if context is lost.
</instructions>
", subagent_type="rrr-roadmapper", description="Create roadmap")
```

**Handle roadmapper return:**

**If `## ROADMAP BLOCKED`:**
- Present blocker information
- Work with user to resolve
- Re-spawn when resolved

**If `## ROADMAP CREATED`:**

Read the created ROADMAP.md and present it nicely inline:

```
---

## Proposed Roadmap

**[N] phases** | **[X] requirements mapped** | All v1 requirements covered ✓

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | [Name] | [Goal] | [REQ-IDs] | [count] |
| 2 | [Name] | [Goal] | [REQ-IDs] | [count] |
| 3 | [Name] | [Goal] | [REQ-IDs] | [count] |
...

### Phase Details

**Phase 1: [Name]**
Goal: [goal]
Requirements: [REQ-IDs]
Success criteria:
1. [criterion]
2. [criterion]
3. [criterion]

**Phase 2: [Name]**
Goal: [goal]
Requirements: [REQ-IDs]
Success criteria:
1. [criterion]
2. [criterion]

[... continue for all phases ...]

---
```

**CRITICAL: Ask for approval before committing:**

Use AskUserQuestion:
- header: "Roadmap"
- question: "Does this roadmap structure work for you?"
- options:
  - "Approve" — Commit and continue
  - "Adjust phases" — Tell me what to change
  - "Review full file" — Show raw ROADMAP.md

**If "Approve":** Continue to commit.

**If "Adjust phases":**
- Get user's adjustment notes
- Re-spawn roadmapper with revision context:
  ```
  Task(prompt="
  <revision>
  User feedback on roadmap:
  [user's notes]

  Current ROADMAP.md: @.planning/ROADMAP.md

  Update the roadmap based on feedback. Edit files in place.
  Return ROADMAP REVISED with changes made.
  </revision>
  ", subagent_type="rrr-roadmapper", description="Revise roadmap")
  ```
- Present revised roadmap
- Loop until user approves

**If "Review full file":** Display raw `cat .planning/ROADMAP.md`, then re-ask.

**Commit roadmap (after approval):**

```bash
git add .planning/ROADMAP.md .planning/STATE.md .planning/REQUIREMENTS.md .planning/phases/
git commit -m "$(cat <<'EOF'
docs: create roadmap ([N] phases)

Phases:
1. [phase-name]: [requirements covered]
2. [phase-name]: [requirements covered]
...

All v1 requirements mapped to phases.
EOF
)"
```

## Phase 10: Done

Present completion with next steps:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► PROJECT INITIALIZED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**[Project Name]**

| Artifact       | Location                    |
|----------------|-----------------------------|
| Project        | `.planning/PROJECT.md`      |
| Config         | `.planning/config.json`     |
| Research       | `.planning/research/`       |
| Requirements   | `.planning/REQUIREMENTS.md` |
| Roadmap        | `.planning/ROADMAP.md`      |

**[N] phases** | **[X] requirements** | Ready to build ✓

───────────────────────────────────────────────────────────────

## ▶ Next Up

**Phase 1: [Phase Name]** — [Goal from ROADMAP.md]

`/rrr:plan-phase 1`

<sub>`/clear` first → fresh context window</sub>

───────────────────────────────────────────────────────────────
```

</process>

<output>

- `.planning/PROJECT.md` (includes Deviation Notes)
- `.planning/MVP_FEATURES.yml` (capability selections)
- `.planning/config.json`
- `.planning/research/` (if research selected)
  - `STACK.md`
  - `FEATURES.md`
  - `ARCHITECTURE.md`
  - `PITFALLS.md`
  - `SUMMARY.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/XX-name/` directories

</output>

<success_criteria>

- [ ] Preflight checks completed (greenfield vs brownfield detection)
- [ ] If RRR already initialized (.planning/STATE.md): User directed to /rrr:progress and command exits
- [ ] If GREENFIELD: Bootstrap completed (Next.js + Tailwind + shadcn/ui + Vitest + Playwright), tests pass, committed
- [ ] If BROWNFIELD: Existing files untouched, only .planning/ artifacts created
- [ ] .planning/ directory created
- [ ] Git repo initialized
- [ ] Brownfield codebase mapping offered (if existing code detected)
- [ ] Capability questionnaire completed (auth, db, payments, storage, analytics, voice, agents, deploy)
- [ ] MVP_FEATURES.yml created with capability selections
- [ ] Deviation Notes collected for any overrides from Preferred Pack
- [ ] Deep questioning completed (threads followed, not rushed)
- [ ] PROJECT.md captures full context + Deviation Notes → **committed**
- [ ] config.json has workflow mode, depth, parallelization → **committed**
- [ ] Research completed (if selected) — 4 parallel agents spawned → **committed**
- [ ] Requirements gathered (from research or conversation)
- [ ] User scoped each category (v1/v2/out of scope)
- [ ] REQUIREMENTS.md created with REQ-IDs → **committed**
- [ ] rrr-roadmapper spawned with context
- [ ] Roadmap files written immediately (not draft)
- [ ] User feedback incorporated (if any)
- [ ] ROADMAP.md created with phases, requirement mappings, success criteria
- [ ] STATE.md initialized
- [ ] REQUIREMENTS.md traceability updated
- [ ] Phase directories created → **committed**
- [ ] User knows next step is `/rrr:plan-phase 1`

**Atomic commits:** Each phase commits its artifacts immediately. If context is lost, artifacts persist.

</success_criteria>
