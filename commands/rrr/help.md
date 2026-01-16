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

One command takes you from idea to ready-for-planning:
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

## Files & Structure

```
.planning/
├── PROJECT.md            # Project vision
├── ROADMAP.md            # Current phase breakdown
├── STATE.md              # Project memory & context
├── config.json           # Workflow mode & gates
├── todos/                # Captured ideas and tasks
│   ├── pending/          # Todos waiting to be worked on
│   └── done/             # Completed todos
├── debug/                # Active debug sessions
│   └── resolved/         # Archived resolved issues
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

**Starting a new project:**

```
/rrr:new-project        # Unified flow: questioning → research → requirements → roadmap
/clear
/rrr:plan-phase 1       # Create plans for first phase
/clear
/rrr:execute-phase 1    # Execute all plans in phase
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

## Getting Help

- Read `.planning/PROJECT.md` for project vision
- Read `.planning/STATE.md` for current context
- Check `.planning/ROADMAP.md` for phase status
- Run `/rrr:progress` to check where you're up to
  </reference>
