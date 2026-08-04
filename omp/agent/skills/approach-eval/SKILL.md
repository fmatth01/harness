---
name: approach-eval
description: Use this skill when the user is choosing between approaches, weighing design alternatives, or comparing trade-offs. Triggers on phrases like "should I use X or Y", "compare approaches for...", "trade-offs between...", "what's the best way to...", "evaluate these options". Refuses to evaluate without explicit constraints. Produces a comparison matrix with problem-specific axes, a defended recommendation, and a sensitivity section. Does NOT do web research — if more info about a candidate is needed, defer to the research skill.
---

# Approach evaluation

Your job is to evaluate candidate approaches against the user's *specific* constraints and produce a defended recommendation. Generic "X is faster, Y is more flexible" output is failure — the skill's value is making the evaluation about *this* situation, not the general case.

## Step 1 — Establish constraints

Before evaluating, all of these must be on the table:

- **Performance target** — concrete numbers if applicable (latency, throughput, accuracy threshold).
- **Complexity budget** — how much engineering effort is acceptable.
- **Time horizon** — when does this need to ship, and how long will it live.
- **Team / familiarity** — who maintains this, what they already know.
- **Integration constraints** — what stack, what existing code, what must not break.

If any are missing or vague, pause and ask the user to fill them in. Refuse to evaluate against unstated constraints — that's how you get generic, useless comparisons.

## Step 2 — Set the candidate set

If the user provided only 1-2 candidates, propose 2-3 more. At least one must *reframe the problem* rather than solve it head-on — e.g., "do you actually need a database here, or would a file work?" / "could this happen at build time instead of runtime?" / "is the right answer to remove the requirement?"

If a candidate needs information you don't have, defer the lookup to the research skill rather than guessing. Do not search the web inline.

## Step 3 — Identify decision axes

Choose axes that actually matter for *this* decision. Do not reuse a generic template — the lazy default of "performance / complexity / maintainability" is almost never the right axis set. Pick 3-5 axes tuned to the specific problem. Examples of axes that earn their place: cold-start cost, debuggability under failure, integration friction with the existing pipeline, time to first working version, scale ceiling before rewrite, vendor lock-in, on-call burden.

## Step 4 — Build the comparison matrix

Candidates as rows, axes as columns. Each cell is a short, concrete claim — not a rating, not a star count. "~30ms p99 single-node" is good; "Fast" is not. Cite where claims come from if non-obvious.

## Step 5 — Recommend

State the recommendation in one sentence. Then 2-4 sentences of explicit reasoning naming which axes drove the decision and which were tie-breakers. Do not hedge. If two options are genuinely equivalent, say so and explain what would tip it.

## Step 6 — Sensitivity ("when this would be wrong")

End with a short section: what change in constraints would flip the recommendation? "If the team gains a dedicated infra engineer, switch to X." "If the latency target tightens below 10ms, Y stops working." This is what turns a recommendation into a durable decision record.

## Required output shape

Use exactly these section headers, in this order:

- `## Constraints (as I understood them)` — bullets
- `## Candidates` — bulleted list including any you proposed and any reframes, each with a one-line description
- `## Comparison` — the matrix table
- `## Recommendation` — one sentence + reasoning
- `## When this would be wrong` — bullets

## Anti-patterns

- Evaluating without explicit constraints. Refuse it.
- Generic axes (the performance/complexity/maintainability trio as a default).
- Star ratings or 1-10 scores. Concrete claims only.
- Hedging recommendations into uselessness. If you can't decide, say what would break the tie.
- Doing web research inline. Delegate to /research.
