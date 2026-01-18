---
name: rrr:help
description: Show available RRR commands and usage guide
---

<objective>
Display the complete RRR command reference.

Output ONLY the reference content below. Do NOT add:

- Project-specific analysis
- Git status or file context
- Next-step suggestions
- Any commentary beyond the reference
  </objective>

<reference>
# RRR Command Reference

**RRR** creates hierarchical project plans optimized for solo agentic development with Claude Code. Built by [Projecta.ai](https://projecta.ai).

## Getting Started

**After install/update:** If you installed from inside Claude Code, type `exit` and restart `claude` so it reloads commands.

**Still seeing "Unknown skill"?** Reinstall with `npx projecta-rrr@latest`, then restart `claude` again.

**Not sure what to run?** Use `/rrr:mvp` — it detects your project state and tells you exactly what to do.

**Pick your start command:**

| Scenario | Command |
|----------|---------|
| New/empty folder (greenfield) | `/rrr:new-project` — bootstraps Next.js/TS baseline if folder is empty |
| Existing repo (brownfield) | `/rrr:map-codebase` (optional) → `/rrr:new-project` |
| RRR already initialized | `/rrr:progress` — if `.planning/STATE.md` exists |
| Not sure which? | `/rrr:mvp` — detects state and routes you |

**MVP Definition of Done at Projecta:** local demo runs + tests pass.

**Overnight automation:** Use `/rrr:overnight` for Pushpa Mode guidance.

## Where to Run Commands

| Environment | What to run | Notes |
|-------------|-------------|-------|
| **Inside Claude Code** | `/rrr:*` slash commands | Interactive planning/execution |
| **Outside Claude Code** | `bash scripts/pushpa-mode.sh` | Unattended overnight runs |
| **npm scripts** | `npm run pushpa`, `npm run e2e` | Convenience wrappers |

**After installing from inside Claude Code:** Exit and restart `claude` to load new commands.

**Pushpa Mode (overnight):** Always run in a separate terminal for true unattended execution.

## Quick Start

1. `/rrr:new-project` - Initialize project (includes research, requirements, roadmap)
2. `/rrr:plan-phase 1` - Create detailed plan for first phase
3. `/rrr:execute-phase 1` - Execute the phase

## Staying Updated

RRR evolves fast. Check for updates periodically:

```
/rrr:whats-new
```

Shows what changed since your installed version. Update with:

```bash
npx projecta-rrr@latest
```

## Core Workflow

```
/rrr:new-project → /rrr:plan-phase → /rrr:execute-phase → repeat
```

### Project Initialization

**`/rrr:new-project`**
Initialize new project through unified flow.

**Automatically bootstraps if needed** — detects if repo is a Next.js project. If not, runs the bootstrap sequence (Next.js + TypeScript + Tailwind + shadcn/ui + Vitest + Playwright) before proceeding.

One command takes you from empty folder to ready-for-planning:
- Bootstrap detection and execution (if needed)
- Deep questioning to understand what you're building
- Optional domain research (spawns 4 parallel researcher agents)
- Requirements definition with v1/v2/out-of-scope scoping
- Roadmap creation with phase breakdown and success criteria

Creates all `.planning/` artifacts:
- `PROJECT.md` — vision and requirements
- `config.json` — workflow mode (interactive/yolo)
- `research/` — domain research (if selected)
- `REQUIREMENTS.md` — scoped requirements with REQ-IDs
- `ROADMAP.md` — phases mapped to requirements
- `STATE.md` — project memory

Usage: `/rrr:new-project`

**`/rrr:bootstrap-nextjs`**
Scaffold Next.js App Router project with Projecta defaults (standalone).

- Next.js (App Router) + TypeScript
- Tailwind CSS + shadcn/ui (with Button component)
- Vitest + Testing Library (smoke unit test)
- Playwright (smoke e2e test)
- `.env.example` with common MVP placeholders

Use this standalone when you only want the bootstrap without RRR planning.
Note: `/rrr:new-project` includes bootstrap automatically.

Usage: `/rrr:bootstrap-nextjs`

**`/rrr:map-codebase`**
Map an existing codebase for brownfield projects.

- Analyzes codebase with parallel Explore agents
- Creates `.planning/codebase/` with 7 focused documents
- Covers stack, architecture, structure, conventions, testing, integrations, concerns
- Use before `/rrr:new-project` on existing codebases

Usage: `/rrr:map-codebase`

### Standalone Commands (deprecated, kept for mid-project use)

These commands are now integrated into `/rrr:new-project` but remain available for mid-project adjustments:

**`/rrr:research-project`** — Re-research a domain (integrated into new-project Phase 6)
**`/rrr:define-requirements`** — Redefine requirements (integrated into new-project Phase 7)
**`/rrr:create-roadmap`** — Recreate roadmap (integrated into new-project Phase 8)

### Phase Planning

**`/rrr:discuss-phase <number>`**
Help articulate your vision for a phase before planning.

- Captures how you imagine this phase working
- Creates CONTEXT.md with your vision, essentials, and boundaries
- Use when you have ideas about how something should look/feel

Usage: `/rrr:discuss-phase 2`

**`/rrr:research-phase <number>`**
Comprehensive ecosystem research for niche/complex domains.

- Discovers standard stack, architecture patterns, pitfalls
- Creates RESEARCH.md with "how experts build this" knowledge
- Use for 3D, games, audio, shaders, ML, and other specialized domains
- Goes beyond "which library" to ecosystem knowledge

Usage: `/rrr:research-phase 3`

**`/rrr:list-phase-assumptions <number>`**
See what Claude is planning to do before it starts.

- Shows Claude's intended approach for a phase
- Lets you course-correct if Claude misunderstood your vision
- No files created - conversational output only

Usage: `/rrr:list-phase-assumptions 3`

**`/rrr:plan-phase <number>`**
Create detailed execution plan for a specific phase.

- Generates `.planning/phases/XX-phase-name/XX-YY-PLAN.md`
- Breaks phase into concrete, actionable tasks
- Includes verification criteria and success measures
- Multiple plans per phase supported (XX-01, XX-02, etc.)

Usage: `/rrr:plan-phase 1`
Result: Creates `.planning/phases/01-foundation/01-01-PLAN.md`

### Execution

**`/rrr:execute-plan <path>`**
Execute a single PLAN.md file.

- Runs plan tasks sequentially
- Creates SUMMARY.md after completion
- Updates STATE.md with accumulated context
- Use for interactive execution with checkpoints

Usage: `/rrr:execute-plan .planning/phases/01-foundation/01-01-PLAN.md`

**`/rrr:execute-phase <phase-number>`**
Execute all unexecuted plans in a phase with parallel background agents.

- Analyzes plan dependencies and spawns independent plans concurrently
- Use when phase has 2+ plans and you want "walk away" execution
- Respects max_concurrent_agents from config.json

Usage: `/rrr:execute-phase 5`

Options (via `.planning/config.json` parallelization section):
- `max_concurrent_agents`: Limit parallel agents (default: 3)
- `skip_checkpoints`: Skip human checkpoints in background (default: true)
- `min_plans_for_parallel`: Minimum plans to trigger parallelization (default: 2)

### Roadmap Management

**`/rrr:add-phase <description>`**
Add new phase to end of current milestone.

- Appends to ROADMAP.md
- Uses next sequential number
- Updates phase directory structure

Usage: `/rrr:add-phase "Add admin dashboard"`

**`/rrr:insert-phase <after> <description>`**
Insert urgent work as decimal phase between existing phases.

- Creates intermediate phase (e.g., 7.1 between 7 and 8)
- Useful for discovered work that must happen mid-milestone
- Maintains phase ordering

Usage: `/rrr:insert-phase 7 "Fix critical auth bug"`
Result: Creates Phase 7.1

**`/rrr:remove-phase <number>`**
Remove a future phase and renumber subsequent phases.

- Deletes phase directory and all references
- Renumbers all subsequent phases to close the gap
- Only works on future (unstarted) phases
- Git commit preserves historical record

Usage: `/rrr:remove-phase 17`
Result: Phase 17 deleted, phases 18-20 become 17-19

### Milestone Management

**`/rrr:discuss-milestone`**
Figure out what you want to build in the next milestone.

- Reviews what shipped in previous milestone
- Helps you identify features to add, improve, or fix
- Routes to /rrr:new-milestone when ready

Usage: `/rrr:discuss-milestone`

**`/rrr:new-milestone <name>`**
Create a new milestone with phases for an existing project.

- Adds milestone section to ROADMAP.md
- Creates phase directories
- Updates STATE.md for new milestone

Usage: `/rrr:new-milestone "v2.0 Features"`

**`/rrr:complete-milestone <version>`**
Archive completed milestone and prepare for next version.

- Creates MILESTONES.md entry with stats
- Archives full details to milestones/ directory
- Creates git tag for the release
- Prepares workspace for next version

Usage: `/rrr:complete-milestone 1.0.0`

### Progress Tracking

**`/rrr:progress`**
Check project status and intelligently route to next action.

- Shows visual progress bar and completion percentage
- Summarizes recent work from SUMMARY files
- Displays current position and what's next
- Lists key decisions and open issues
- Offers to execute next plan or create it if missing
- Detects 100% milestone completion

Usage: `/rrr:progress`

### Session Management

**`/rrr:resume-work`**
Resume work from previous session with full context restoration.

- Reads STATE.md for project context
- Shows current position and recent progress
- Offers next actions based on project state

Usage: `/rrr:resume-work`

**`/rrr:pause-work`**
Create context handoff when pausing work mid-phase.

- Creates .continue-here file with current state
- Updates STATE.md session continuity section
- Captures in-progress work context

Usage: `/rrr:pause-work`

### Debugging

**`/rrr:debug [issue description]`**
Systematic debugging with persistent state across context resets.

- Gathers symptoms through adaptive questioning
- Creates `.planning/debug/[slug].md` to track investigation
- Investigates using scientific method (evidence → hypothesis → test)
- Survives `/clear` — run `/rrr:debug` with no args to resume
- Archives resolved issues to `.planning/debug/resolved/`

Usage: `/rrr:debug "login button doesn't work"`
Usage: `/rrr:debug` (resume active session)

### Todo Management

**`/rrr:add-todo [description]`**
Capture idea or task as todo from current conversation.

- Extracts context from conversation (or uses provided description)
- Creates structured todo file in `.planning/todos/pending/`
- Infers area from file paths for grouping
- Checks for duplicates before creating
- Updates STATE.md todo count

Usage: `/rrr:add-todo` (infers from conversation)
Usage: `/rrr:add-todo Add auth token refresh`

**`/rrr:check-todos [area]`**
List pending todos and select one to work on.

- Lists all pending todos with title, area, age
- Optional area filter (e.g., `/rrr:check-todos api`)
- Loads full context for selected todo
- Routes to appropriate action (work now, add to phase, brainstorm)
- Moves todo to done/ when work begins

Usage: `/rrr:check-todos`
Usage: `/rrr:check-todos api`

### Skills Management

**`/rrr:list-skills`**
List all available skills (vendored and community).

- Shows Projecta skills (default stack)
- Shows Anthropic skills (vendored from upstream)
- Shows community skills (user-installed)
- Includes tags, descriptions, and usage

Usage: `/rrr:list-skills`

**`/rrr:install-skill <url-or-name>`**
Install a skill from GitHub or skillsmp.com marketplace.

- Fetches SKILL.md from source
- Validates format
- Saves to `.claude/skills/community/`
- Updates local registry

Usage: `/rrr:install-skill https://github.com/user/repo/blob/main/SKILL.md`
Usage: `/rrr:install-skill my-skill-name`

**`/rrr:search-skills <query>`**
Search for skills on skillsmp.com marketplace.

- Returns top 10 results with descriptions and stars
- Offers to install selected skill

Usage: `/rrr:search-skills react patterns`

### Utility Commands

**`/rrr:help`**
Show this command reference.

**`/rrr:whats-new`**
See what's changed since your installed version.

- Shows installed vs latest version comparison
- Displays changelog entries for versions you've missed
- Highlights breaking changes
- Provides update instructions when behind

Usage: `/rrr:whats-new`

**`/rrr:mvp`**
Smart router that detects your project state and tells you what to run next.

- Detects if `.planning/STATE.md` exists → routes to `/rrr:progress`
- Detects if repo has code (package.json, .git, src/) → suggests `/rrr:map-codebase` then `/rrr:new-project`
- Otherwise → suggests `/rrr:new-project`

Usage: `/rrr:mvp`

**`/rrr:overnight`**
Pushpa Mode guidance: preflight checks and run instructions.

- Checks if project is initialized
- Checks if `scripts/pushpa-mode.sh` exists (gives copy instructions if not)
- Provides exact command to run in a normal terminal
- Recommends running outside Claude Code interactive session

Usage: `/rrr:overnight`

## Files & Structure

```
.planning/
├── PROJECT.md            # Project vision
├── ROADMAP.md            # Current phase breakdown
├── STATE.md              # Project memory & context
├── VISUAL_PROOF.md       # Visual proof run log (append-only)
├── config.json           # Workflow mode & gates
├── artifacts/            # Build & test artifacts
│   └── playwright/       # Playwright test output
│       ├── report/       # HTML report
│       └── test-results/ # Screenshots, traces, videos
├── pushpa/               # Pushpa Mode state
│   └── ledger.json       # Persistent run state
├── todos/                # Captured ideas and tasks
│   ├── pending/          # Todos waiting to be worked on
│   └── done/             # Completed todos
├── debug/                # Active debug sessions
│   └── resolved/         # Archived resolved issues
├── logs/                 # Execution logs
│   └── skills_*.log      # Skills loading logs
├── codebase/             # Codebase map (brownfield projects)
│   ├── STACK.md          # Languages, frameworks, dependencies
│   ├── ARCHITECTURE.md   # Patterns, layers, data flow
│   ├── STRUCTURE.md      # Directory layout, key files
│   ├── CONVENTIONS.md    # Coding standards, naming
│   ├── TESTING.md        # Test setup, patterns
│   ├── INTEGRATIONS.md   # External services, APIs
│   └── CONCERNS.md       # Tech debt, known issues
└── phases/
    ├── 01-foundation/
    │   ├── 01-01-PLAN.md
    │   └── 01-01-SUMMARY.md
    └── 02-core-features/
        ├── 02-01-PLAN.md
        └── 02-01-SUMMARY.md
```

## Workflow Modes

Set during `/rrr:new-project`:

**Interactive Mode**

- Confirms each major decision
- Pauses at checkpoints for approval
- More guidance throughout

**YOLO Mode**

- Auto-approves most decisions
- Executes plans without confirmation
- Only stops for critical checkpoints

Change anytime by editing `.planning/config.json`

## Common Workflows

**Starting a new project (from empty folder):**

```
/rrr:new-project        # Bootstraps repo (if needed) → questionnaire → requirements → roadmap
/clear
/rrr:plan-phase 1       # Create plans for first phase
/clear
/rrr:execute-phase 1    # Execute all plans in phase
```

That's it! `/rrr:new-project` handles everything from bootstrap to roadmap.

**Overnight mode: Pushpa Mode**

Run phases unattended while you sleep with token-safe budgets. After `npx projecta-rrr`:

```
bash scripts/pushpa-mode.sh
# or
npm run pushpa
```

Prerequisites:
1. Run `/rrr:new-project` first
2. Set all required API keys (based on your MVP_FEATURES.yml)
3. Recommend enabling YOLO mode in config.json

MVP_FEATURES.yml locations (checked in order):
- `./MVP_FEATURES.yml` (preferred, repo root)
- `./.planning/MVP_FEATURES.yml` (legacy)

Pushpa Mode will:
- Plan and execute phases sequentially
- Skip phases marked with `HITL_REQUIRED: true`
- Run visual proof (Playwright) after each phase
- Enforce budgets (max phases, time, calls)
- Stop on repeated failures (prevents infinite loops)
- Generate report at `.planning/PUSHPA_REPORT.md`
- Persist state to `.planning/pushpa/ledger.json`

**Budgets (override via env vars):**
- `MAX_PHASES_PER_RUN=3` — phases per run
- `MAX_TOTAL_MINUTES=180` — total runtime
- `MAX_TOTAL_RRR_CALLS=25` — Claude calls
- `MAX_CONSECUTIVE_FAILURES=3` — failures before stop

**Where to run:** Recommended outside Claude Code for true unattended runs.
The script detects if running inside Claude Code and prompts: `Continue running inside Claude Code? (y/N)`. Default is **No** — press Enter to exit with instructions to run externally.

**Verification Ladder**

Plans are automatically classified by `frontend_impact` (replaces legacy `ui_affecting`):

| frontend_impact | unit_tests | playwright | chrome_visual_check |
|-----------------|------------|------------|---------------------|
| true | Yes | Yes (Step 1) | Yes (Step 2) |
| false | Yes | No | No |

Planner adds `verification.frontend_impact: true|false` frontmatter automatically based on file paths and keywords. See `rrr/references/frontend-impact-detection.md` for classification rules.

**Visual Proof: Two-Step Verification**

Frontend-impacting plans require **both** verification steps to be green:

1. **Step 1: Playwright** — Automated E2E tests (baseline verification)
2. **Step 2: Chrome** — `claude --chrome` visual check (human-level UX verification)

Both steps run automatically after `/rrr:execute-phase` and `/rrr:execute-plan` when `frontend_impact: true`.

**Step 1: Playwright Commands**
```
npm run e2e              # Run Playwright tests (headless)
npm run e2e:headed       # Run with browser visible
npm run e2e:ui           # Playwright UI mode (interactive)
npm run visual:open      # Open HTML report
```

**Step 2: Chrome Visual Check**
```
bash scripts/visual-proof.sh --chrome    # Run chrome step only
claude --chrome                          # Direct chrome invocation
```

**Manual Two-Step Workflow**
```bash
# Step 1: Playwright
bash scripts/visual-proof.sh

# Step 2: Chrome (requires GUI)
bash scripts/visual-proof.sh --chrome
```

**Artifacts location:**
```
.planning/
├── VISUAL_PROOF.md              # Append-only run log (both steps)
└── artifacts/
    ├── playwright/
    │   ├── report/              # HTML report (index.html)
    │   └── test-results/        # Screenshots, traces, videos
    └── chrome/
        └── {plan-id}/           # Chrome visual check artifacts
            ├── screenshot-*.png # Captured screenshots
            └── session.json     # Chrome session metadata
```

**Modes (in `.planning/config.json`):**
- `playwright` — headless (default)
- `playwright_headed` — headed if TTY
- `hybrid` — headless first, prompt for interactive on failure
- `interactive_only` — skip Playwright, show manual checklist

**VISUAL_PROOF.md Entries:**
- **Playwright step:** datetime, plan/phase ID, commands run, pass/fail, console errors, artifact paths
- **Chrome step:** datetime, plan/phase ID, visual check result, screenshots taken, UX observations

**Environment Variables:**
- `FRONTEND_IMPACT=true` — Force chrome step (auto-detected from plan frontmatter)
- `PLAN_ID=xx-yy` — Set plan ID for artifact organization
- `PUSHPA_MODE=true` — Skip chrome step if no GUI available

**Bootstrap only (no planning):**

```
/rrr:bootstrap-nextjs   # Just scaffold Next.js + testing + shadcn
```

**Resuming work after a break:**

```
/rrr:progress  # See where you left off and continue
```

**Adding urgent mid-milestone work:**

```
/rrr:insert-phase 5 "Critical security fix"
/rrr:plan-phase 5.1
/rrr:execute-plan .planning/phases/05.1-critical-security-fix/05.1-01-PLAN.md
```

**Completing a milestone:**

```
/rrr:complete-milestone 1.0.0
/rrr:new-milestone  # Start next milestone
```

**Capturing ideas during work:**

```
/rrr:add-todo                    # Capture from conversation context
/rrr:add-todo Fix modal z-index  # Capture with explicit description
/rrr:check-todos                 # Review and work on todos
/rrr:check-todos api             # Filter by area
```

**Debugging an issue:**

```
/rrr:debug "form submission fails silently"  # Start debug session
# ... investigation happens, context fills up ...
/clear
/rrr:debug                                    # Resume from where you left off
```

**Using skills:**

Skills load automatically based on plan content. To list available skills:

```
/rrr:list-skills                              # Show all vendored + community skills
```

To install community skills:

```
/rrr:search-skills react patterns             # Search marketplace
/rrr:install-skill https://github.com/...     # Install from GitHub
```

Skills are declared in PLAN.md frontmatter (auto-inferred if not specified):

```yaml
---
skills:
  - projecta.testing
  - projecta.visual-proof
---
```

## Skills Directory

```
~/.claude/skills/                   # Global install
├── registry.json                   # Skill metadata + resolution
├── projecta/                       # Projecta custom skills
│   ├── testing-vitest-playwright/
│   ├── visual-proof/
│   ├── cloudflare-r2/
│   ├── nextjs-typescript/          # Default skill (always loads)
│   ├── shadcn-ui/
│   └── mcp-stack/
├── upstream/anthropic/             # Vendored Anthropic skills
│   ├── pdf/
│   ├── xlsx/
│   └── ...
└── community/                      # Community skill packs
    ├── vercel/                     # Vercel agent skills (included in npm)
    │   ├── vercel-react-best-practices/
    │   └── web-design-guidelines/
    └── droid-tings/                # AI/ML skills (vendor on demand)
        └── (vendor with scripts/vendor-droid-tings-skills.sh)
```

**Vendoring Community Skills:**

```bash
# Vercel skills (small, included in npm package)
bash scripts/vendor-vercel-skills.sh

# droid-tings (large, not in npm - vendor on demand)
bash scripts/vendor-droid-tings-skills.sh --list           # See available
DROID_TINGS_ALLOWLIST="axolotl,unsloth" bash scripts/vendor-droid-tings-skills.sh
```

## Getting Help

- Read `.planning/PROJECT.md` for project vision
- Read `.planning/STATE.md` for current context
- Check `.planning/ROADMAP.md` for phase status
- Run `/rrr:progress` to check where you're up to
  </reference>
