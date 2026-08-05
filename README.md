# harness

My omp agent configuration: settings, context files, skills, plugin registry commands, and ponytail preferences. Everything is symlinked from `~/.omp/agent` so edits made through omp (e.g. `omp config set`) land in this repo — `git diff` shows config drift.

## Contents

```
omp/
  agent/
    config.yml    settings (modelRoles, statusLine, task, …)
    AGENTS.md     global behavioral guidelines
    RULES.md      sticky rules
    skills/       user skills (approach-eval, research)
  install.sh      idempotent installer / re-linker
  update.sh       `omp --update` handler (git pull + re-install + omp update)
ponytail/
  config.json     ponytail extension preferences
```

Not included (machine-local by design): credentials (`~/.omp/agent/agent.db`), sessions, plugin caches, and git identity.

## Install on a new machine

Prerequisites: omp installed, git identity set (`git config --global user.name/email`).

```sh
git clone git@github.com:fmatth01/harness.git ~/harness
~/harness/omp/install.sh
```

What it does:

- symlinks `config.yml`, `AGENTS.md`, `RULES.md`, `skills/*`, and `ponytail/config.json` into place (existing real files are moved to `*.pre-dotfiles` once)
- adds both plugin marketplaces and installs `ponytail@ponytail` + `omp-sub-burndown-indicator@nszceta` (skipped when already present)
- installs an `omp()` shell hook so `omp --update` commits local edits, merges them with origin/main and pushes, re-runs install.sh, then updates omp itself
- `RULES.md` is a union-merge file (`.gitattributes`): if two machines add rules on the same lines, sync keeps both instead of aborting
- honors `PI_CODING_AGENT_DIR` if you relocate the agent dir

Safe to re-run anytime — it re-points symlinks and never touches files it didn't create.

## After install

- Authenticate: `/login` per provider (or point omp at an auth broker). Credentials never come from this repo.
- The burndown-indicator plugin renders its status line at the next session start.
- Update the shared config from this machine: `cd ~/harness && git add -A && git commit -m "…" && git push`.
- Update a machine from the repo: `omp --update` (pulls, re-runs install.sh, then updates omp itself).
