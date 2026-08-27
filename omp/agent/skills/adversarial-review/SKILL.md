---
name: adversarial-review
description: MANUAL ONLY. Invoke exclusively when the user explicitly asks for an adversarial review (e.g. "run adversarial review", "AR this", "do the reviewer-critic loop on this plan/diff"). Do NOT auto-invoke on plan completion, code completion, or any other implicit trigger — this is never a default gate on finishing or committing work. When invoked, runs a bounded reviewer-critic loop (Adversarial Review, arXiv:2608.18167) that freezes the current artifact (a `local://<slug>-plan.md` plan, or the current code diff), forces evidence-typed disagreement between an independent reviewer and critic, and lets the main agent edit only after the review converges. Complements, and does not replace, the always-on Architecture/Correctness advisors, which review continuously and independently rather than through this frozen-artifact exchange.
---

# Adversarial Review

## Overview

Before executing a non-trivial plan, or completing a non-trivial code change, run this loop. The artifact (plan document or diff) is frozen while a reviewer and a critic exchange review text; the main agent edits only after they converge. Self-review is not review, and a single reviewer is not enough — the critic's job is to audit the reviewer, not rubber-stamp it.

## When to use

Trigger ONLY when the user explicitly asks for it — phrases like "run adversarial review", "AR this", "reviewer-critic this plan/diff", or an explicit request to use this skill by name. Never invoke automatically on plan completion, code completion, or before considering work done; there is no implicit gate of any kind. When invoked, review whatever artifact is current: the active `local://<slug>-plan.md` plan, or `git diff HEAD` if no plan is active.

## The loop

Given artifact version N (a plan document, or `git diff HEAD` for code) — do not edit it during this loop:

1. Spawn a **Reviewer** subagent via `task` (read-only investigative tools only: `read`, `grep`, `glob`, `ast_grep`, `web_search` — no edits). Give it the frozen artifact, the original user ask verbatim, and relevant project docs/rules. It reviews for correctness, root cause vs. symptom, edge cases, and scope (does this stay within what was asked?). It ends with exactly one verdict line: `APPROVE` or `NEEDS_CHANGES: <one-line summary of top issue>`.
2. Spawn a **Critic** subagent via `task` (same read-only tool set), fresh, with the same full context as the reviewer plus the reviewer's latest review. Its job has two dimensions: is every flagged issue real (or spurious)? did the reviewer miss any real issue? It ends with exactly one verdict line, one of:
   - `AGREE` — accepts the review as-is.
   - `DISAGREE_EVIDENCE: <file:line or concrete artifact citation>` — cites specific evidence in the artifact/codebase that contradicts a flag.
   - `DISAGREE_CONCERN: <specific unsubstantiated concern>` — an epistemic objection with no contradicting evidence to cite.
3. Route the critic's verdict back to the reviewer:
   - `AGREE`: the review is consistent. Stop the inner loop.
   - `DISAGREE_EVIDENCE`: the reviewer revises the flag based on the cited evidence, or drops it. Continue to step 2 with the revised review.
   - `DISAGREE_CONCERN`: the reviewer must either cite specific evidence in the artifact that confirms the flag (keep it) or cite evidence that refutes it (drop it) — never capitulate to a concern with no evidence on either side, and never drop a legitimate flag just to converge faster. Continue to step 2 with the reviewer's response.
4. Continue until the reviewer and critic reach `AGREE`, or 5 inner rounds are reached (one round = one reviewer response + one critic response). If 5 rounds pass without agreement, stop and report the unresolved disagreement to the user instead of picking a side.

## After the inner loop converges

- If the reviewer approved on its first pass (`APPROVE`, zero flags) AND the critic agreed on its first pass (no back-and-forth needed): the artifact is accepted. Proceed (execute the plan, or consider the code change done) — do not run another round.
- Otherwise, the main agent edits the artifact once, addressing every flag in the consistent review, producing version N+1. Start a fresh inner loop on version N+1 (steps 1-4).
- Cap at 2 outer iterations (2 artifact revisions). If the artifact still doesn't converge cleanly after 2 revisions, stop and report the remaining disagreement to the user instead of iterating further.

## Common mistakes

- Editing the artifact during the inner loop. Reviewer and critic exchange text only; the artifact stays frozen until convergence.
- Skipping the critic, or treating `DISAGREE_CONCERN` as grounds to drop a flag without the reviewer citing refuting evidence — that recreates the paper's measured false-consensus failure (critic yields to an unsubstantiated rebuttal).
- Accepting every reviewer flag without critic pushback — that recreates the paper's measured over-decomposition failure (thin, hedged findings pile up unaudited).
- Letting the reviewer's flags expand beyond the user's original ask ("what if the user also wants X") — the critic must challenge scope creep the same way it challenges unsubstantiated bugs; an unrequested addition is a spurious flag.
- Using this as an automatic gate — it is not. Never invoke it just because a plan or code change finished; only run it when the user explicitly asks.
