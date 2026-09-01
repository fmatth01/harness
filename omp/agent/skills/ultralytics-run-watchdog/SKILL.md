---
name: ultralytics-run-watchdog
description: "Monitor ultralytics training runs in tmux with per-epoch val stats (mAP50, mAP50-95, fitness, epochs-since-best) and finish notifications. Use when launching or watching any YOLO train run."
---

# Ultralytics Training-Run Watchdog

Launch long training runs in tmux windows (user visibility) and watch per-epoch validation stats with an awk pipeline that survives ultralytics' ANSI/tqdm log noise. Model-agnostic: works for detect/seg/obb/cls — the val "all" row always ends with `mAP50 mAP50-95` (for seg those are the Mask variants, which is what the user wants).

## Launch pattern (never blocking bash)

```bash
mkdir -p <repo>/data/logs
tmux new-window -t <session> -n <descriptive-run-name> \
  'cd <repo> && <train command> 2>&1 | tee data/logs/<run>.log'
```

- Descriptive window name per run (e.g. `train-r1`), never a constant.
- Always tee to a log — watchers and you both read the log, not the pane.
- Tell the user: `tmux attach -t <session>`, the window name, the log path.

## Per-epoch stats watcher

The val "all" row appears exactly once per completed epoch, in file order — **count the lines, never parse epoch headers** (headers carry ANSI `\x1b[K` prefixes and `\r`-joined tqdm chunks; python `splitlines` hides the `\r` while awk does not, so header regexes break in one of the two).

`tools/epoch_stats.awk` (copy into the repo; RUN is the run label):

```awk
# Fed by: tail -n +1 -f data/logs/<run>.log | awk -v RUN=<run> -f epoch_stats.awk
# Val "all" row ends: ... mAP50 mAP50-95 (seg: the Mask columns)
{ sub(/\033\[[0-9;]*[A-Za-z]/, "", $0); n = split($0, parts, "\r"); $0 = parts[n] }
/^[[:space:]]*all[[:space:]]/ {
    epoch++
    map50 = $(NF - 1) + 0
    map5095 = $NF + 0
    fit = 0.9 * map5095 + 0.1 * map50    # ultralytics fitness; change weights via -v
    if (fit > best + 1e-9) { best = fit; bestep = epoch }
    printf "[%s] ep %3d  mAP50=%.4f  mAP50-95=%.4f  fitness=%.4f  since_best=%3d  (best %.4f @ ep %d)\n", RUN, epoch, map50, map5095, fit, epoch - bestep, best, bestep
    fflush()
}
/Stopping training early/ || /"completed"/ { print "== " RUN " finished =="; fflush() }
```

Deploy (one tail+awk per run, `& wait` keeps the window alive):

```bash
tmux new-window -t <session> -n watchdog \
  'cd <repo> && tail -n +1 -f data/logs/r1.log | awk -v RUN=R1 -f tools/epoch_stats.awk & tail -n +1 -f data/logs/r2.log | awk -v RUN=R2 -f tools/epoch_stats.awk & wait'
```

`tail -n +1` replays history so the watcher backfills; `fflush()` is mandatory (awk buffers when piped).

## Waking the agent on completion (IMPORTANT)

Never rely on polling the log from the session — you will go stale (real incident: 24 epochs finished while the poller showed 45/100). Instead, for every long run spawn ONE background marker-wait job whose **auto-delivery wakes the session** when it completes:

```bash
# Training run (log-marker based):
bash(async): while ! grep -qE 'Stopping training early|"completed"' data/logs/<run>.log 2>/dev/null; do sleep 30; done; echo '== WAKE: <RUN> DONE =='; tail -3 data/logs/<run>.log | tr '\r' '\n' | tail -2

# Eval / non-logging process (process-exit based; match the unique cmdline):
bash(async): while pgrep -f '<unique part of the command line>' >/dev/null 2>&1; do sleep 20; done; echo '== WAKE: <JOB> DONE =='; tail -5 data/logs/<job>.log 2>/dev/null | tr '\r' '\n' | tail -3
```

- Run these with `async: true` and `timeout: 0` (no deadline — they can wait overnight).
- The finished job delivers its result automatically, waking the agent even while idle — that is the resume trigger; the delivered tail contains the state to continue from.
- One wake job per long-running process. Process-exit watches need a cmdline unique to that run (never `python 04_eval.py` bare).

## Finish notification (optional, non-agent)

Watchdog loop with a **started flag** — never fire on "process absent" alone (a not-yet-started run trips it):

```bash
while true; do for r in R1 R2; do
  if pgrep -f "<train cmd --only $r>" >/dev/null; then touch data/logs/$r.started
  elif [ -f data/logs/$r.started ] && [ ! -f data/logs/$r.done ]; then touch data/logs/$r.done
    echo "== $r finished $(date) =="; notify-send "<proj>" "$r finished" 2>/dev/null || true
  fi; done; sleep 30; done
```

## Pitfalls (all hit in production)

- **ANSI + `\r`**: strip `\x1b[...` escapes, then take the LAST `\r`-chunk before matching — tqdm bars precede real content on the same `\n` line.
- **Val lines are the ground truth**: one per epoch, in order. Header parsing failed 3 separate implementations; the counter works first try.
- **Python watcher scripts can silently print nothing** when spawned through wrapper shells (block buffering / fd quirks). Prefer awk in a pipeline; if you must use python, `python3 -u` and `flush=True` everywhere.
- **MLflow metric keys** get parens stripped server-side (`metrics/mAP50-95M`); query history with the stripped name. `mlflow.log_metrics` REJECTS parens — strip them before logging.
- **Early stopping**: `patience=20` → stop = best epoch + 20. `since_best` in the watcher output tells you how close.
- Epoch wall time at run start (warmup/cache) can be 10x steady state — don't extrapolate ETA from epoch 1.

## Verification

After deploying: the watcher pane shows one `[RUN] ep N ...` line per completed epoch, backfilled to the current epoch, with `best` tracking; the finish banner appears at early stop or run end. Test on a historical log first (`tail -n +1 data/logs/old.log | awk ...`) before attaching to a live run. Then spawn the wake job and confirm it exists in the job list.
