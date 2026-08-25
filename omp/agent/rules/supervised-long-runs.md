---
name: supervised-long-runs
description: "Long-running work (corpus scans, training, multi-minute jobs) must run supervised via hub/tmux and never block the main session; waits must watch for failure as well as success so runs never stop silently"
condition:
  - "for (vid|video|sid) in (VIDS|VIDEOS|VIDEO_IDS|videos|video_ids)"
  - "for .* in VIDS:"
  - "for .* in (VIDS|VIDEOS|VIDEO_IDS|videos):"
  - "sleep\\s+[0-9]{3,}"
  - "Notify Main the moment"
  - "hub-send to Main"
  - "R2_DONE|R3_DONE"
scope: ["tool:eval", "tool:bash", "tool"]
---

Never run whole-corpus work (loops over all videos/frames/masks, training, propagation, any process expected to take minutes) in main-chat `eval` or `bash` — it blocks the user from asking questions (the 900s global-bank scan did exactly this).

Launch supervised instead: write the analysis as a script under `scripts/` (reusing existing helpers), run it via `hub op:start` with a unique name (or a tmux session with a tee'd log), print per-item progress lines with `flush=True` so the user can attach and watch, and monitor non-blocking with `hub op:wait`/`op:logs`. Small single-file/one-video computations may stay inline; anything that scans the whole corpus or runs long goes supervised.

Watch for failure as well as success — a run that stops silently is the failure mode to avoid:

- With `hub op:wait`, never wait only for exit and assume success. Wait on a pattern that covers both outcomes (`pattern: "DONE|FAILED|Traceback|ERROR"`) and inspect which matched, or wait for exit then check the exit code and the log tail.
- With a tmux/log watcher, grep for both markers: `while ! grep -qE 'DONE|FAILED|Traceback' <log>; do sleep 30; done` — then check which one appeared.
- If a process exits with neither marker, treat it as a failure and investigate. A crashed run must never look finished.

Never:

- Block the main session with a long one-shot `sleep NNN; <poll>` (N >= 300) — it ties up the session and triggers loop detection. If hub-managed waiting is impossible, run a background poll with `bash` `async: true`: `while ! grep -q '<done-pattern>' <log>; do sleep 30; done`, then ONE short status call. Poll delay is ~30s, never 600-2400s blocking sleeps.
- Spawn a task/scout subagent whose only job is to watch a running process or log and message the main session when it completes — a subagent must do real work: edit code, investigate, or produce an artifact. Use a deterministic watcher instead (a tmux window running a pgrep/grep loop that reacts the instant the process exits: banner + notify-send + done-flag file), or `hub wait`/`hub jobs` when the process is hub-managed. Never substitute an hour-long blocking sleep; a watcher reacts immediately, a sleep wastes time if the process finishes early.

When the run finishes (success or failure) and is handled: clean up — `hub op:stop` the process and kill the tmux session/window (`tmux kill-session -t <name>` or `kill-window`). Never leave finished tmux windows behind.
