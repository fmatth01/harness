---
name: python-dead-code-audit
description: "Audit a Python repo for dead code using stdlib AST import-graph gates (reachability + test coverage), classify dead/flagged/keep, verify per criterion."
---

# Python dead-code audit (AST import-graph gates)

Use when asked to "remove dead code", "clean up the repo", or "find what's unused" in a Python repo, or when a repo's CLI surface is smaller than its file inventory suggests.

## Flow
1. **Find the real roots.** Read the CLI entry point(s) (argparse handlers, console_scripts). Root modules = handler imports, not the whole package.
2. **Write a reachability gate FIRST** — it is both the discovery tool and the verification gate:
   - Scan `rglob("*.py")` (skip `.venv`, `__pycache__`, `.git`, tests/, data/).
   - Parse with stdlib `ast` (no deps). Collect every `Import`/`ImportFrom`, including function-level imports (CLIs lazy-import handlers!).
   - **Resolve imported names, not just modules**: `from pipeline import store` must edge to `pipeline/store.py`, not just `pipeline/__init__.py`.
   - Resolve relative imports: `from .x import y` in module `a.b.c` → `a.b.x`; `from ..y` → drop 2 package levels.
   - BFS **outward** from roots along edges (file → files it imports). The common bug is walking backwards (adding files that *import* a reachable file) — that finds nothing.
   - Allowlist intentional exceptions (hook scripts, test-only helpers, empty `__init__`s) with a reason per entry.
3. **Do not trust "reachable == live".** A superseded iteration can be reachable through the entry point (old CLI subcommands). Check the user's stated surface; if a subtree is only reached by a command being retired, retire the command first, then the subtree becomes unreachable and deletable.
4. **Reachability is per-file, not per-dir.** One CSV in a dead dir may be read by live code (`ground_truth.py` reading `annotation/helicoil_gt.csv`). Grep inbound edges per file before deleting a dir.
5. **Classify, don't guess**: DEAD (delete), FLAGGED (keep, list with reason — test fixtures cited by history docs, fallback defaults still code-referenced), KEEP (hooks/CI invoke it even though nothing imports it — check `.githooks/`, `.github/workflows/`).
6. **Separate test-coverage gate**: same AST machinery, seeds = test files, reports pipeline modules no test imports (transitive BFS counts).
7. **Verify per criterion**: pytest, reachability gate, coverage gate, `--help` per command, grep docs for deleted names (past-tense deletion records in ADRs are fine; claims that things still exist are not).

## Pitfalls seen in the field
- Non-UTF8 `.py` inside `.venv/` when the venv lives in the repo — skip `.venv` before parsing.
- Deleted data dirs still referenced as *fallback defaults* in live modules — keep the constant if any code path references it, even if the current callers pass explicit args.
- A "test" that has no `__main__` but is run via `python -m` executes nothing — vacuous battery legs pass trivially. Check for `__main__` blocks in subprocess-run suites.
- Outdated tests may assert the *opposite* of the agreed surface (pinning old CLI commands as live) — they must be deleted with the retired code, not updated.
- Hook scripts enforce conventions (commit-message scope prefixes, TESTING.md row hashes) — read them before committing; a commit message that fails the hook wastes a cycle, and green rows without hashes warn on every subsequent commit.
