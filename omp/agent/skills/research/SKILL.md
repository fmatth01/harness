---
name: research
description: Use this skill when the user wants to inventory existing solutions, libraries, papers, or prior art related to a problem. Triggers on phrases like "is there a library for...", "how do people usually solve...", "what's the standard approach to...", "what's been written about...", "find prior art for...". Spawns a subagent to do the actual searching, then returns a structured inventory. Does NOT recommend, rank, or pick winners — for that, defer to the approach-eval skill.
---

# Research: prior-art inventory

Your job is to inventory what already exists for the problem the user described. You do not recommend, rank, or pick winners. The output is a map of the landscape.

## Step 1 — Establish scope

Read the project's `CLAUDE.md` at the repo root for stack, conventions, and constraints. If `CLAUDE.md` is missing or doesn't cover the relevant area, ask one targeted clarifying question (stack + version + hard constraints) and wait for an answer before proceeding.

## Step 2 — Delegate to a research subagent

Spawn an Explore subagent with this brief. The subagent does the searching; you only see its structured return value.

> Inventory prior art for: `<problem statement>`.
> Project stack: `<stack from CLAUDE.md>`.
> Hard constraints: `<constraints from CLAUDE.md>`.
> Budget: at most 6 total searches across all sources combined. Prefer 1-2 broad searches over many narrow ones. Stop early if you have 5+ candidates with maintenance signals. Do not chase completeness — return what you have when the cap is reached, with a footnote naming what was skipped.
>
> Search across:
> - **GitHub** — `gh search repos` and `gh search code` for libraries and example implementations.
> - **Web** — Exa (MCP) or web_search (built-in) for articles, blogs, and docs. Prefer original sources over aggregators.
> - **Academic** — for ML/algorithms problems, search arXiv (MCP) plus Google Scholar via web search. Capture publication year and rough citation count where available.
>
> Return ONLY the structured table specified below. No preamble. No recommendation. No raw snippets.

## Step 3 — Required output format

A single markdown table with these columns, in this order:

| Name | Type | Link | One-line description | Maintenance/recency | Fit notes |

Column rules:
- **Type**: one of `lib` | `paper` | `article` | `repo` | `service`.
- **Maintenance/recency**: for repos — last commit date + star count + license. For papers — year + venue + rough citation count. For articles — year.
- **Fit notes**: 1-2 sentences. Cross-reference the project's stack and conventions. Flag anything that would clash. This is the column that makes the inventory more useful than a Google search — don't shortchange it.

## Step 4 — Cap and disclose

Surface at most 8 candidates. If more strong candidates exist, narrow by (1) maintenance signal, then (2) stack fit. Add a one-line footnote naming what was excluded and why. Save the final table to docs/research/<short-name>.md and surface the file path + a 3-line file summary to the main session.

## Step 5 — Refuse to recommend

Do not pick a winner. Do not order candidates by quality. Do not add a "best for most users" column. If the user asks you to choose, refuse.

## Anti-patterns

- Returning raw search snippets or full READMEs to the main session — the subagent reads those; the main session sees only the table.
- Padding the inventory with weak matches to hit a count target.
- Including options you couldn't verify (no hallucinated repo names, no plausible-sounding paper titles without a confirmed link).
- Recommending. Just don't.
