---
name: long-runs-in-tmux
description: "Whole-corpus loops and any long-running work must run as scripts in tmux via hub op:start, never in main-chat eval/bash; clean up tmux windows when finished"
condition: ["for (vid|video|sid) in (VIDS|VIDEOS|VIDEO_IDS|videos|video_ids)", "for .* in VIDS:", "for .* in (VIDS|VIDEOS|VIDEO_IDS|videos):"]
scope: ["tool:eval", "tool:bash"]
---

Never run whole-corpus work (loops over all videos/frames/masks, training, propagation, any process expected to take minutes) in main-chat `eval` or `bash` — it blocks the user from asking questions (the 900s global-bank scan did exactly this).

Instead: write the analysis as a script under `scripts/` (reusing `rle_decode`/`load_anchors`/etc.), launch it in tmux via `hub op:start` with a unique name, print per-video/per-25-frame progress lines with `flush=True` so the user can attach and watch, and monitor with `hub op:wait`/`op:logs` (non-blocking for the user).

When the run finishes and is verified: clean up — `hub op:stop` the process and kill the tmux session/window (`tmux kill-session -t <name>` or kill-window). Never leave finished tmux windows behind.

Small single-file/one-video computations may stay inline in `eval`/`bash`; anything that scans the whole corpus or runs long goes to tmux.