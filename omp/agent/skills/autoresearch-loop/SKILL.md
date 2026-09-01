---
name: autoresearch-loop
description: "Run a researcher-steered model retraining autoresearch loop: launch/supervise runs, consult researcher between runs, derive paired per-metric noise-floor bands, apply conf-swept test-gate-only promotion logic."
---

# Autoresearch Loop — replicable procedure

Run a model-retraining autoresearch loop with researcher steering, honest promotion
metrics, and survival-grade process mechanics. Distilled from the tool-seg retrain
iteration-2 loop (`/home/finn/work/tool-seg-retrain/data/reports/iteration-2-autoresearch.md`
= the full reference; read it when working in that repo).

## When to use
User asks for a retraining/autoresearch loop with researcher consultation, or any loop
where an agent trains models repeatedly and must not fabricate winners.

## The loop skeleton
1. **Plan** (decision-complete, `local://<slug>-plan.md`, propose via `xd://propose`):
   fixed corpus/split, production contract (deployment threshold, compute budget), run
   count, consultation protocol, champion rule, deliverable rule.
2. **Researcher consultation between every run** (SLOW model, e.g. `ml-researcher` agent
   pinned `@slow`): brief at `local://iteration-brief.md` (results table, production
   contract, constraint box, questions a-d), report at `local://iteration-recommendation.md`
   (archive to `data/reports/researcher-<N>-<k>.md`). The researcher decides the NEXT run's
   recipe. NEVER substitute executor recipes; on 5 consecutive spawn failures PAUSE and
   tell the user (GPU idle). User directives can arrive mid-consultation via hub — they
   override the brief; record them in the traceability table.
3. **Every decision traceable to production**: record in a table (columns: # | choice |
   where | value | production requirement | verdict | action).
4. **Champion rule** (researcher-decided): judge ONLY on the test split at the PRODUCTION
   operating point. **Primary = the production miss metric on the GENUINELY UNSEEN
   subset** — single-station corpora have near-duplicate test blocks (img:* 50-frame
   blocks from the same recording): split p:*/v:* unseen groups (primary) vs near-dup
   blocks (sanity check, never pooled; pooled blends dilute real effects ~2x).
   Production hyperparameters are NOT sacred — the user can unlock conf/imgsz etc.;
   re-verify the gate at the new operating point.
5. **Conf-swept verdicts (the S6 rule — a fixed-conf win condition is gameable)**: a
   lower threshold can make the champion's OWN weights "win" (R18 best.pt @0.05 passed
   its own win test). Predict ONCE at conf 0.02 (per-frame records: max box conf per
   frame + group + GT flag), threshold offline for ANY conf. Verdicts = matched-fp
   comparisons (run's miss at the conf where its fp equals the champion's), never
   miss-at-fixed-conf. Find the operating point at the fp/miss knee (below it, the
   fp population switches on).
6. **Noise floor**: per-metric, TWO-SIDED, PAIRED: `N = max(2·sd(paired pooled delta over
   groups), |replicate delta|)`. Marginal bootstraps are too wide for clustered test
   sets. Recompute on the unseen subset. Same-frame comparisons (checkpoint vs conf vs
   conf) use paired McNemar, never N bands.
7. **Shipping checkpoint is a measured decision**: periodic checkpoints (save_period=2)
   evaluated with the production gate; judge by the POST-AUGMENTATION tail of the
   conf-swept curve (fp variance lives in the mosaic phase: sd 10-28pp in-mosaic vs
   1-2pp after; best.pt is usually a mosaic-phase checkpoint; val fitness selects the
   worst unseen checkpoint because val can't see the failure). Dump per-frame records
   before deleting checkpoints.
8. **Forensic fp attribution** (when fp explodes): cluster the fp frames by object
   position/size/conf — one static object (unannotated in train) is the usual cause;
   check which augmentation first synthesizes its size class (scale) and which makes
   its colour inseparable (HSV). Augmentation broke a supervised negative, not novelty.

## Loop insurance (failures MUST surface — an unread traceback is not a failed job)
- **Every job**: `tools/run_job.sh NAME [--log FILE] CMD...` → detached setsid launch,
  truncated log, `__DONE__ <code>` marker appended on exit. Wait: `tools/wait_job.sh NAME
  [TIMEOUT_S]` → fails on nonzero exit or timeout and prints the log tail. NEVER
  background a job and forget it; never poll pgrep alone as completion.
- **Artifact validation**: every artifact consumer validates schema (expected keys,
  conf field, counts) + freshness (mtime > job start) before use. Stale files from an
  older conf look valid to a naive existence check — the schema check catches them.
- **GPU concurrency rule**: ONE GPU job at a time (31 GB card; concurrent jobs OOM
  silently — noise-floor groups died while the gate curve ran, 2026-08-19). Serialize.
- **Process mechanics (the expensive lessons)**: long GPU jobs: `setsid -f` launch into
  a hardened tmux (exit-empty off, remain-on-exit on, destroy-unattached off); NEVER
  pipe through `tee` (SIGPIPE death). Supervisor: pgrep with a `$` anchor (prevents
  self-match) or the marker file; process-exit + stall (log mtime > 30 min) wake via
  async bash (`timeout: 0`). **NEVER do post-training work in the training process**
  (cached datasets ≈ 40 GB RSS: evals/forks die silently, 3× observed). Training process
  trains and exits; readouts run in a fresh process; the loop merges results + marks the
  experiment tracker FINISHED. Read TEST metrics only; tracker per-run values often =
  last val step (never for decisions). Predict on long image lists OOMs (whole list
  becomes one batch) — chunk (~128). Pause/resume: atomic checkpoint writes (tmp +
  os.replace), `--resume` appends to the log.
- **TMUX layout** (user wants long jobs visible in named windows; clean up dead ones):
  - `0 shell` (control), `N <RUN>` (training tail), `N+1 <RUN>-watch` (epoch stats),
    optional `<RUN>-curve` (gate-curve pane) — kill finished windows, they are dead
    weight once the job's data is in JSON.
  - Watchdog panes are INFORMATIONAL (val proxies are often INVERTED vs the production
    gate — measured: recall + while fp tripled). A gate-curve pane built on REAL gate
    metrics CAN bold the champion: `tools/gate_stats.awk` renders
    `GATE ep=… umiss=… ufp=… miss=… fp=… run2=… mAP=… held=…` lines, FULL-HISTORY
    repaint (every checkpoint visible grey, exactly one bold `<< CHAMP` row, champion
    status line at the bottom); bands via `-v UMISS= -v UFP= -v NMAP=` (<=0 = disabled;
    the fp band is what excludes fp-poisoned low-miss epochs). Window command:
    `tail --retry -n +1 -f data/logs/<run>_curve.log | awk -v RUN=<RUN> -v CONF=<opconf> -f tools/gate_stats.awk`.
  - Kill-pattern footgun: `pgrep -f gate_curve` also matches the pane's own
    `tail … gate_curve_r18.log` pipeline (SIGTERM kills the window) — anchor the pattern
    (`pgrep -f "gate_curve.py"`) or use `pkill -f '^…'`.
  - Pane content sits at the TOP after a repaint — check `head`, not `tail`, when
    verifying a pane (the classic "nothing is updating" false alarm).
- **Schedule discipline**: patience == declared epochs; full LR decay + ≥15 clean
  (mosaic-off) epochs must execute, or both tails of the schedule are deleted.

## Verification before each launch
- Summary entry exists with both checkpoint readouts + gate keys; no early-stop line;
  last.pt exists; fresh-process readout deterministic.
- Corpus/split frozen (md5 of the frozen split file), leakage check, held-class balance
  check, exact split counts. Leakage gate: near-dup blocks within ±50 global-counter
  steps of train frames should be excluded or reported separately.
- Gate numbers verified against the researcher's probes before the run's verdicts.
- Gate infrastructure keeps imgsz + conf parameterized (a 1280 model gated at 1024 is
  an invalid readout); readouts report the trained imgsz AND the default, key-tagged.
