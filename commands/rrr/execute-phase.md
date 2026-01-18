---
name: rrr:execute-phase
description: Execute all plans in a phase with wave-based parallelization
argument-hint: "<phase-number>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Task
  - TodoWrite
  - AskUserQuestion
---

<objective>
Execute all plans in a phase using wave-based parallel execution.

Orchestrator stays lean: discover plans, analyze dependencies, group into waves, spawn subagents, collect results. Each subagent loads the full execute-plan context and handles its own plan.

Context budget: ~15% orchestrator, 100% fresh per subagent.
</objective>

<execution_context>
@~/.claude/rrr/references/principles.md
@~/.claude/rrr/references/ui-brand.md
@~/.claude/rrr/workflows/execute-phase.md
</execution_context>

<context>
Phase: $ARGUMENTS

@.planning/ROADMAP.md
@.planning/STATE.md
</context>

<process>
1. **Validate phase exists**
   - Find phase directory matching argument
   - Count PLAN.md files
   - Error if no plans found

2. **Discover plans**
   - List all *-PLAN.md files in phase directory
   - Check which have *-SUMMARY.md (already complete)
   - Build list of incomplete plans

3. **Group by wave**
   - Read `wave` from each plan's frontmatter
   - Group plans by wave number
   - Report wave structure to user

4. **Load skills for plans**
   Before executing, load skills for each plan:
   - Read plan frontmatter for `skills:` array
   - If empty, infer from plan content using registry inference rules
   - Always include default skill (`projecta.nextjs-typescript`) unless `skills_mode: minimal`
   - Load skill contents from `~/.claude/skills/` or `./.claude/skills/`
   - Log: `[RRR] Skills for {plan}: {skills} ({lines} lines)`

5. **Execute waves**
   For each wave in order:
   - For each plan, inject `<skills>` block into executor prompt
   - Spawn `rrr-executor` for each plan in wave (parallel Task calls)
   - Wait for completion (Task blocks)
   - Verify SUMMARYs created
   - Proceed to next wave

6. **Aggregate results**
   - Collect summaries from all plans
   - Report phase completion status

7. **Run phase verification ladder** (after all plans complete)

   Determine phase surface by checking plan frontmatters:
   - If ANY plan has `verification.surface: ui_affecting` → phase is UI_AFFECTING
   - If ALL plans have `verification.surface: backend_only` → phase is BACKEND_ONLY

   a. **Run unit tests** (always, if they exist):
      ```bash
      # Check if unit tests exist
      ls src/**/*.test.ts __tests__/**/*.ts 2>/dev/null
      # If found:
      npm run test:unit || npm test
      ```

   b. **Run e2e tests** (if UI_AFFECTING AND e2e tests exist):
      ```bash
      # Check for e2e tests
      ls e2e/*.spec.ts 2>/dev/null
      # If found, run via script or directly:
      bash scripts/visual-proof.sh
      # or
      npx playwright test
      ```

   c. **Run chrome visual check** (if UI_AFFECTING AND not Pushpa mode):
      ```bash
      # Skip in Pushpa mode
      if [[ -n "${PUSHPA_MODE:-}" ]]; then
        echo "SKIP: Chrome visual check disabled in Pushpa Mode"
      else
        bash scripts/chrome-visual-check.sh
      fi
      ```

   d. **Confirm artifact locations** (if playwright ran):
      - `.planning/artifacts/playwright/test-results/` — screenshots, traces, videos
      - `.planning/artifacts/playwright/report/` — HTML report

   e. **Update VISUAL_PROOF.md** (append-only):
      ```markdown
      ## Run: {ISO-8601 datetime}

      **Phase:** {phase_number}-{phase_name}
      **Surface:** {ui_affecting | backend_only}
      **Commands:**
      - `npm test` — {pass/fail or "skipped"}
      - `npx playwright test` — {pass/fail or "skipped" or "n/a (backend_only)"}
      - `chrome_visual_check` — {pass/fail or "skipped (Pushpa)" or "n/a (backend_only)"}

      **Result:** {PASS|FAIL} ({passed}/{total} steps)

      ### Console Errors
      {List any console errors observed, or "None"}

      ### Artifact Paths
      - Report: `.planning/artifacts/playwright/report/index.html`
      - Failures: `.planning/artifacts/playwright/test-results/`

      ---
      ```

   **Verification by phase surface:**

   | Surface | unit_tests | playwright | chrome_visual_check |
   |---------|------------|------------|---------------------|
   | ui_affecting | Yes | Yes | Yes (skip in Pushpa) |
   | backend_only | Yes | No | No |

   **Visual proof failure does NOT block phase completion** — logged as warning only.
   Continue to verification step regardless of test results.

8. **Verify phase goal**
   - Spawn `rrr-verifier` subagent with phase directory and goal
   - Verifier checks must_haves against actual codebase (not SUMMARY claims)
   - Creates VERIFICATION.md with detailed report
   - Route by status:
     - `passed` → continue to step 9
     - `human_needed` → present items, get approval or feedback
     - `gaps_found` → present gaps, offer `/rrr:plan-phase {X} --gaps`

9. **Update roadmap and state**
   - Update ROADMAP.md, STATE.md

10. **Update requirements**
   Mark phase requirements as Complete:
   - Read ROADMAP.md, find this phase's `Requirements:` line (e.g., "AUTH-01, AUTH-02")
   - Read REQUIREMENTS.md traceability table
   - For each REQ-ID in this phase: change Status from "Pending" to "Complete"
   - Write updated REQUIREMENTS.md
   - Skip if: REQUIREMENTS.md doesn't exist, or phase has no Requirements line

11. **Commit phase completion**
    Bundle all phase metadata updates in one commit:
    - Stage: `git add .planning/ROADMAP.md .planning/STATE.md`
    - Stage REQUIREMENTS.md if updated: `git add .planning/REQUIREMENTS.md`
    - Stage VISUAL_PROOF.md if updated: `git add .planning/VISUAL_PROOF.md`
    - Commit: `docs({phase}): complete {phase-name} phase`

12. **Offer next steps**
    - Route to next action (see `<offer_next>`)
</process>

<offer_next>
**MANDATORY: Present copy/paste-ready next command.**

After verification completes, route based on status:

| Status | Route |
|--------|-------|
| `gaps_found` | Route C (gap closure) |
| `human_needed` | Present checklist, then re-route based on approval |
| `passed` + more phases | Route A (next phase) |
| `passed` + last phase | Route B (milestone complete) |

---

**Route A: Phase verified, more phases remain**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► PHASE {Z} COMPLETE ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Phase {Z}: {Name}**

{Y} plans executed
Goal verified ✓

───────────────────────────────────────────────────────────────

## ▶ Next Up

**Phase {Z+1}: {Name}** — {Goal from ROADMAP.md}

`/rrr:plan-phase {Z+1}`

<sub>`/clear` first → fresh context window</sub>

───────────────────────────────────────────────────────────────

**Also available:**
- `/rrr:verify-work {Z}` — manual acceptance testing before continuing
- `/rrr:discuss-phase {Z+1}` — gather context first

───────────────────────────────────────────────────────────────
```

---

**Route B: Phase verified, milestone complete**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► MILESTONE COMPLETE 🎉
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**v1.0**

{N} phases completed
All phase goals verified ✓

───────────────────────────────────────────────────────────────

## ▶ Next Up

**Audit milestone** — verify requirements, cross-phase integration, E2E flows

`/rrr:audit-milestone`

<sub>`/clear` first → fresh context window</sub>

───────────────────────────────────────────────────────────────

**Also available:**
- `/rrr:verify-work` — manual acceptance testing
- `/rrr:complete-milestone` — skip audit, archive directly

───────────────────────────────────────────────────────────────
```

---

**Route C: Gaps found — need additional planning**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 RRR ► PHASE {Z} GAPS FOUND ⚠
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Phase {Z}: {Name}**

Score: {N}/{M} must-haves verified
Report: `.planning/phases/{phase_dir}/{phase}-VERIFICATION.md`

### What's Missing

{Extract gap summaries from VERIFICATION.md}

───────────────────────────────────────────────────────────────

## ▶ Next Up

**Plan gap closure** — create additional plans to complete the phase

`/rrr:plan-phase {Z} --gaps`

<sub>`/clear` first → fresh context window</sub>

───────────────────────────────────────────────────────────────

**Also available:**
- `cat .planning/phases/{phase_dir}/{phase}-VERIFICATION.md` — see full report
- `/rrr:verify-work {Z}` — manual testing before planning

───────────────────────────────────────────────────────────────
```

After user runs `/rrr:plan-phase {Z} --gaps`:
1. Planner reads VERIFICATION.md gaps
2. Creates plans 04, 05, etc. to close gaps
3. User runs `/rrr:execute-phase {Z}` again
4. Execute-phase runs incomplete plans (04, 05...)
5. Verifier runs again → loop until passed
</offer_next>

<wave_execution>
**Parallel spawning:**

Spawn all plans in a wave with a single message containing multiple Task calls.
Include the `<skills>` block loaded in step 4 for each plan:

```
Task(prompt="Execute plan at {plan_01_path}\n\n{skills_01_block}\n\nPlan: @{plan_01_path}\nProject state: @.planning/STATE.md", subagent_type="rrr-executor")
Task(prompt="Execute plan at {plan_02_path}\n\n{skills_02_block}\n\nPlan: @{plan_02_path}\nProject state: @.planning/STATE.md", subagent_type="rrr-executor")
Task(prompt="Execute plan at {plan_03_path}\n\n{skills_03_block}\n\nPlan: @{plan_03_path}\nProject state: @.planning/STATE.md", subagent_type="rrr-executor")
```

Where `{skills_XX_block}` is the `<skills>` content containing skill SKILL.md files specific to that plan.

All three run in parallel. Task tool blocks until all complete.

**No polling.** No background agents. No TaskOutput loops.
</wave_execution>

<checkpoint_handling>
Plans with `autonomous: false` have checkpoints. The execute-phase.md workflow handles the full checkpoint flow:
- Subagent pauses at checkpoint, returns structured state
- Orchestrator presents to user, collects response
- Spawns fresh continuation agent (not resume)

See `@~/.claude/rrr/workflows/execute-phase.md` step `checkpoint_handling` for complete details.
</checkpoint_handling>

<deviation_rules>
During execution, handle discoveries automatically:

1. **Auto-fix bugs** - Fix immediately, document in Summary
2. **Auto-add critical** - Security/correctness gaps, add and document
3. **Auto-fix blockers** - Can't proceed without fix, do it and document
4. **Ask about architectural** - Major structural changes, stop and ask user

Only rule 4 requires user intervention.
</deviation_rules>

<commit_rules>
**Per-Task Commits:**

After each task completes:
1. Stage only files modified by that task
2. Commit with format: `{type}({phase}-{plan}): {task-name}`
3. Types: feat, fix, test, refactor, perf, chore
4. Record commit hash for SUMMARY.md

**Plan Metadata Commit:**

After all tasks in a plan complete:
1. Stage plan artifacts only: PLAN.md, SUMMARY.md
2. Commit with format: `docs({phase}-{plan}): complete [plan-name] plan`
3. NO code files (already committed per-task)

**Phase Completion Commit:**

After all plans in phase complete (step 7):
1. Stage: ROADMAP.md, STATE.md, REQUIREMENTS.md (if updated), VERIFICATION.md
2. Commit with format: `docs({phase}): complete {phase-name} phase`
3. Bundles all phase-level state updates in one commit

**NEVER use:**
- `git add .`
- `git add -A`
- `git add src/` or any broad directory

**Always stage files individually.**
</commit_rules>

<success_criteria>
- [ ] All incomplete plans in phase executed
- [ ] Each plan has SUMMARY.md
- [ ] Unit tests run (if `src/**/*.test.ts` or `__tests__/**/*.ts` exist)
- [ ] E2E tests run (if `e2e/*.spec.ts` exist)
- [ ] VISUAL_PROOF.md updated with run results (append-only)
- [ ] Artifact paths confirmed: `.planning/artifacts/playwright/`
- [ ] Phase goal verified (must_haves checked against codebase)
- [ ] VERIFICATION.md created in phase directory
- [ ] STATE.md reflects phase completion
- [ ] ROADMAP.md updated
- [ ] REQUIREMENTS.md updated (phase requirements marked Complete)
- [ ] User informed of next steps
</success_criteria>
