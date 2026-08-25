---
name: no-notifier-agents
description: "Never spawn a subagent solely to watch a long process and notify when it finishes — use a deterministic watcher (tmux watchdog, hub wait/jobs, done-flag files) or resume next work cycle"
condition: ["Notify Main the moment", "hub-send to Main", "R2_DONE|R3_DONE"]
scope: "tool"
---

Never spawn a task/scout agent whose only job is to watch a running process or log and message you when it completes. A subagent must do real work: edit code, investigate, or produce an artifact. When a long process is running and completion is the only pending dependency: (1) set up a deterministic watcher instead — a tmux window running a pgrep/grep loop that reacts the instant the process exits (banner + notify-send + touch a done-flag file), or `hub wait`/`hub jobs` when the process is hub-managed; (2) NEVER use long blocking sleeps (`sleep 3600` or similar) as a substitute — a sleep wastes time if the process finishes early, while the watcher reacts immediately; (3) yield, and resume when the user says continue, when the next work cycle starts, or when a reminder arrives. Do not poll in a blocking bash call and do not spawn agents for wake-ups.