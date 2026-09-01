---
name: propose-plan-canonical-slug
description: "Use when writing a plan for approval via xd://propose — the proposal reads the session's canonical plan file (the \"Existing plan:\" slug), so a fresh-slug plan shows stale content; replace the canonical file first."
---

# Proposing a plan: the canonical-slug trap

## Symptom
Plan approval review shows an OLD/stale plan ("this is the old plan again") even though the new plan was just written to a fresh `local://<new-slug>-plan.md`.

## Root cause
`write xd://propose` presents the session's **canonical** plan file — the slug named in the plan-mode prompt's "Existing plan: `local://<canonical-slug>-plan.md`" line (for this session: `local://tool-seg-retrain-plan.md`). A plan written to a different slug is never shown; the canonical file still holds the previous task's content. Plan-mode's "Different task → create fresh `local://<slug>-plan.md`" guidance is for record-keeping only — the proposal still reads the canonical file.

## Fix (before the `xd://propose` write)
1. Write the NEW plan's full content into the canonical file path (the "Existing plan:" slug from the plan-mode prompt) with `write` (full replacement).
2. Propose with the canonical slug: `write` content to `xd://propose` (title text; slug matches the canonical file).
3. Verify the review shows the new plan. If it still shows stale content, the canonical slug differs from the one assumed — re-read the plan-mode prompt's "Existing plan:" line and repeat with the correct path.

## Notes
- `write` (full replace) for a different task's plan; `edit` (incremental) for a continuing task's plan updates.
- Keeping both files is fine: the task-specific slug file is the record; the canonical file is the proposal source. They can be identical.
- The canonical slug is session-specific (it was `tool-seg-retrain-plan` in this session) — always derive it from the plan-mode prompt, never assume a fixed name.
