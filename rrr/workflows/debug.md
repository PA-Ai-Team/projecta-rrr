# Debug Workflow (DEPRECATED)

This workflow has been consolidated into the `rrr-debugger` agent.

**Location:** `agents/rrr-debugger.md`

**Reason:** The rrr-debugger agent contains all debugging expertise. Loading a separate workflow into orchestrator context was wasteful.

**Migration:**
- `/rrr:debug` now spawns `rrr-debugger` agent directly
- All debugging methodology lives in the agent file
- Templates remain at `rrr/templates/DEBUG.md`

See `agents/rrr-debugger.md` for debugging expertise.
