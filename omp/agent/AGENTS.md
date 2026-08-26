# Global Behavioral Guidelines

## 1. Think Before Coding
Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing:
- State your assumptions explicitly.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted on decisions of any size.
- If something is unclear, stop and name what's confusing.

## 2. Surgical Changes
Touch only what you must. Clean up only your own mess.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, surface it clearly — don't delete it.

Rewrites:
- Prefer small targeted edits for small changes; reserve full-file rewrites for wholesale restructures.
- Before any full-file rewrite, snapshot the original (cp to /tmp, or git stash-style), reconstruct, diff the reconstruction against the snapshot, then run. The diff catches dropped blocks and transcription drift at zero cost.
- A rewrite must prove equivalence to what it replaced: byte-identical or behaviorally verified outputs.
- Verify with stderr visible. A silent-crash run is a failed run, not a passing one. When diffing regenerated outputs, save the old copies before overwriting — comparing against stale files a crashed run never touched is false evidence.

## 3. Goal-Driven Execution
Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan, with clear steps and verification checks.

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
Speak up when success criteria are weak — tighten them before starting.
