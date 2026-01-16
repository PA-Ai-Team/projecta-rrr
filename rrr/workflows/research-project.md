# Research Project Workflow

## DEPRECATED

**This workflow has been consolidated into the rrr-researcher agent.**

The research methodology for project research now lives in:
- `agents/rrr-researcher.md`

The `/rrr:research-project` command spawns 4 parallel rrr-researcher agents:
- Stack agent -> .planning/research/STACK.md
- Features agent -> .planning/research/FEATURES.md
- Architecture agent -> .planning/research/ARCHITECTURE.md
- Pitfalls agent -> .planning/research/PITFALLS.md

The orchestrator synthesizes SUMMARY.md after all agents complete.

**Migration:** No action needed - the command handles this automatically.

---

*Deprecated: 2026-01-15*
*Replaced by: agents/rrr-researcher.md*
