---
name: supervised-long-runs
description: "Never block the main session for more than 15 seconds — any work expected to take longer must run in the background (hub/tmux supervised, async bash, or a delegated subagent); waits must watch for failure as well as success so runs never stop silently"
condition:
  - "for (vid|video|sid) in (VIDS|VIDEOS|VIDEO_IDS|videos|video_ids)"
  - "for .* in VIDS:"
  - "for .* in (VIDS|VIDEOS|VIDEO_IDS|videos):"
  - "sleep\\s+[0-9]{2,}"
  - "Notify Main the moment"
  - "hub-send to Main"
  - "R2_DONE|R3_DONE"
scope: ["tool:eval", "tool:bash", "tool"]
---

The main session must never be blocked for more than 15 seconds. Any work expected to exceed that — a computation, a scan, a wait — goes to the background; inline main-chat `eval`/`bash` calls must return within ~15s. This ceiling is the reason the background machinery exists, not the other way round.

Background paths, chosen by kind of work:

- Long jobs (whole-corpus loops over all videos/frames/masks, training, propagation, anything taking minutes): write the analysis as a script under `scripts/` (reusing existing helpers), run it via `hub op:start` with a unique name (or a tmux session with a tee'd log), print per-item progress lines with `flush=True` so the user can attach and watch, and monitor non-blocking with `hub op:wait`/`op:logs`.
- Delegable work: spawn a `task` subagent — subagents run in the background by default, so the main session stays interactive.
- One-shot waits: `bash` with `async: true`.

Small single-file/one-video computations that finish well under the ceiling may stay inline; anything that risks exceeding it goes to the background.

Watch for failure as well as success — a run that stops silently is the failure mode to avoid:

- With `hub op:wait`, never wait only for exit and assume success. Wait on a pattern that covers both outcomes (`pattern: "DONE|FAILED|Traceback|ERROR"`) and inspect which matched, or wait for exit then check the exit code and the log tail.
- With a tmux/log watcher, re-grep the log every ~30s until `DONE|FAILED|Traceback` appears — then check which one matched.
- If a process exits with neither marker, treat it as a failure and investigate. A crashed run must never look finished.

Never:

- Block the main session with a long one-shot `sleep NNN; <poll>` — it ties up the session and triggers loop detection. If hub-managed waiting is impossible, run a background poll with `bash` `async: true` that re-checks the log every ~30s, then ONE short status call. Poll delays belong in background loops only, never in foreground calls.
- Spawn a task/scout subagent whose only job is to watch a running process or log and message the main session when it completes — a subagent must do real work: edit code, investigate, or produce an artifact. Use a deterministic watcher instead (a tmux window running a pgrep/grep loop that reacts the instant the process exits: banner + notify-send + done-flag file), or `hub wait`/`hub jobs` when the process is hub-managed. Never substitute an hour-long blocking sleep; a watcher reacts immediately, a sleep wastes time if the process finishes early.

When the run finishes (success or failure) and is handled: clean up — `hub op:stop` the process and kill the tmux session/window (`tmux kill-session -t <name>` or `kill-window`). Never leave finished tmux windows behind.
