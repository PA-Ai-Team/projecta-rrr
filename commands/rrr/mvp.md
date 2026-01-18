---
name: rrr:mvp
description: One-command router - detects project state and tells you exactly what to run next
---

<objective>
Detect project state and provide the exact next command to run.

Do NOT execute any commands yourself. Just detect and route.
</objective>

<behavior>
1. **Check for existing RRR initialization:**
   - If `.planning/STATE.md` exists → project is already initialized
   - Route: Tell user to run `/rrr:progress`
   - Offer: "Want me to run `/rrr:progress` for you now?"

2. **Check for existing codebase (brownfield):**
   - If any of these exist: `package.json`, `.git/`, `src/`, `app/`, `lib/`
   - Route: Suggest `/rrr:map-codebase` (optional) then `/rrr:new-project`
   - Message: "Detected existing codebase. Recommended path:
     1. `/rrr:map-codebase` — analyze your code first (optional but recommended)
     2. `/rrr:new-project` — initialize RRR planning

     Want me to start with `/rrr:map-codebase`?"

3. **Empty/greenfield folder:**
   - If none of the above conditions match
   - Route: Run `/rrr:new-project`
   - Message: "Empty folder detected. Ready to bootstrap and initialize.

     Run `/rrr:new-project` to:
     - Bootstrap Next.js + TypeScript + Tailwind + shadcn/ui + testing
     - Go through project questionnaire
     - Generate requirements and roadmap

     Want me to run `/rrr:new-project` for you now?"
</behavior>

<output_format>
Keep output short and actionable:

```
## RRR Project State

**Status:** [Initialized | Brownfield | Greenfield]

**Next command:** `/rrr:...`

[Brief explanation of why]

---

Want me to run it now?
```
</output_format>

<constraints>
- Do NOT run destructive commands
- Do NOT modify any files
- Only detect and print the recommended command
- If user confirms, THEN run the suggested command
</constraints>
