---
name: no-blocking-sleep-polls
description: "Never block the session with long one-shot sleep polls; let the watched process ping back via hub wait/logs"
condition: "sleep\\s+[0-9]{3,}"
scope: "tool:bash"
---

Never block the main session with a long one-shot `sleep NNN; <poll>` bash command (N >= 300) — it ties up the session and triggers loop detection. The watched process pings the agent, not the other way round:

1. Launch the long-running job with `hub` op:"start" (or keep the tmux+tee session) so it is a supervised process.
2. Wait for its completion/pattern with `hub` op:"wait" (for="exit" or pattern) or `hub` op:"logs" — hub delivers when the process signals readiness/exit, so the process pings you.
3. If hub-managed waiting is not possible, run a background poll loop with `bash` `async: true`: `while ! grep -q '<done-pattern>' <log>; do sleep 30; done`, then check the result with ONE short status call.

Poll delay is ~30s, never 600-2400s blocking sleeps.