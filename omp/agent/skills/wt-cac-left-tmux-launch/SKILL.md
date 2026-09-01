---
name: wt-cac-left-tmux-launch
description: "Launch long-running repo jobs in tmux sessions (user rule), tee logs to data/logs; pause/resume via tmux."
---

# Long-running runs launch in tmux, never hub processes

User rule (stated emphatically 2026-08-24): **always** launch long-running jobs (SAM2 candidate extraction, matching, training, any multi-hour GPU run) in a tmux session, NOT via `hub op:start`.

## Launch recipe

1. `tmux kill-session -t <name> 2>/dev/null` to clear a stale session of the same name.
2. `tmux new-session -d -s <name> '<cd repo && exec .venv/bin/python scripts/... 2>&1 | tee data/logs/<name>.log'`
   - Session name convention: `cac-*` (e.g. `cac-gen15`, prior `cac-match2`, `cac-autogen-probe`).
   - Always tee to `data/logs/<name>.log` — the log is the evidence source for WORKFLOW amendments and for the user to `tail -f`.
3. Verify: `tmux ls` shows the session; `tail -6 data/logs/<name>.log` shows startup lines.

## Pause / resume

- Pause: `tmux kill-session -t <name>` (hard kill is safe — generators fsync per frame and resume from `.tmp`/`.progress` sidecars). Prefer `tmux send-keys -t <name> C-c` for graceful stop.
- Resume: re-run the same launch command; scripts auto-resume from sidecars.
- Check progress: `tail -f data/logs/<name>.log` (tell the user this path — they watch it themselves).

## Why

- User expects to see runs in their tmux sessions (they have several attached: `cac-left`, `sam-smoke`, `tool-retrain`).
- Hub processes are invisible to the user; a hub-launched run triggered "not seeing it".
