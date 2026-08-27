# harness

My omp agent configuration: settings, context files, tool-scoped rules, skills, plugin registry commands, and ponytail preferences. Everything is symlinked from `~/.omp/agent` so edits made through omp (e.g. `omp config set`) land in this repo — `git diff` shows config drift.

## Contents

```
omp/
  agent/
    config.yml    settings (modelRoles, statusLine, task, …)
    AGENTS.md     global behavioral guidelines
    RULES.md      generic one-line rules (union-merged on pull)
    rules/        discrete tool-scoped rules: name/condition/scope frontmatter + body
    models.yml    extra model providers (langgraph calculator agent)
    WATCHDOG.yml  dual advisor roster (Adversarial - Architecture, Adversarial - Correctness)
    lsp.json      LSP server overrides (Python/TS/JS/JSON/YAML/Bash root markers)
    skills/       user skills (approach-eval, research, omp-harness-dotfiles)
  install.sh      idempotent installer / re-linker
  pull-models.sh  OPT-IN Ollama model downloads (~59GB; install.sh never auto-downloads)
  update.sh       `omp --update` handler (git pull + re-install + omp update)
tmux/
  tmux.conf       tmux config (tpm + catppuccin + resurrect/continuum + yank; wheel scrolls, mouse drag copies via pbcopy)
docs/
  local-llms.md   local LLM field for 32GB M1 Pro (models, runtimes, pitfalls)
  tmux.md         tmux ecosystem, terminal/theme/font evaluation, cheat sheet
  langgraph.md    LangChain/LangGraph explainer + local quickstart
ponytail/
  config.json     ponytail extension preferences
```

Rules come in two forms: `RULES.md` holds generic one-liners (union-merged on conflict), and `rules/` holds discrete files whose `name`/`condition`/`scope` frontmatter fires per tool match. The long-run discipline that once spanned several rules (`long-runs-in-tmux`, `no-blocking-sleep-polls`, `no-notifier-agents`) now lives in one `main-session-unblocked` rule: never block the main session past 15s — run long work supervised in the background and watch for failure, not just success.

Not included (machine-local by design): credentials (`~/.omp/agent/agent.db`), sessions, plugin caches, and git identity.

## Install on a new machine

Prerequisites: omp installed, git identity set (`git config --global user.name/email`). Homebrew is optional — it's used to install the JetBrains Mono Nerd Font (status-line icons), tmux, and is skipped when absent.

```sh
git clone git@github.com:fmatth01/harness.git ~/harness
~/harness/omp/install.sh
```

What it does:

- symlinks `config.yml`, `AGENTS.md`, `RULES.md`, `models.yml`, `skills/*`, `rules/*`, and `ponytail/config.json` into place (existing real files are moved to `*.pre-dotfiles` once); symlinks `WATCHDOG.yml` and `SYSTEM.md` when present (guarded — only if the file exists in the repo)
- prints `WARN:` for anything under `~/.omp/agent/{skills,rules}` that is machine-local or links outside the repo — drift shows up on every install run
- installs the JetBrains Mono Nerd Font via Homebrew (when present) so status-line icons render, plus both plugin marketplaces and installs `ponytail@ponytail` + `omp-sub-burndown-indicator@nszceta` (skipped when already present)
- installs tmux (upgrades to 3.7 when present), clones tpm, and symlinks `tmux/tmux.conf` — plugins install on the first `tmux` run
- sets `VISUAL`/`EDITOR` in the shell rc when unset (defaults to `code --wait` when VS Code is installed, else `vim`)
- prints a pointer to `omp/pull-models.sh` — local LLM models are downloaded ONLY on demand (install.sh never auto-pulls them)
- installs pyright, ruff, typescript-language-server, biome, yaml-language-server, bash-language-server (Homebrew) plus vscode-langservers-extracted and typescript (npm -g, skipped with a WARN when npm is absent) so LSP diagnostics/navigation work the same on every machine
- installs an `omp()` shell hook so `omp --update` commits local edits, merges them with origin/main and pushes, re-runs install.sh, then updates omp itself
- `RULES.md` is a union-merge file (`.gitattributes`): if two machines add rules on the same lines, sync keeps both instead of aborting
- honors `PI_CODING_AGENT_DIR` if you relocate the agent dir

Safe to re-run anytime — it re-points symlinks and never touches files it didn't create.

## After install

- Authenticate: `/login` per provider (or point omp at an auth broker). Credentials never come from this repo.
- The burndown-indicator plugin renders its status line at the next session start.
- Update the shared config from this machine: `cd ~/harness && git add -A && git commit -m "…" && git push`.
- Update a machine from the repo: `omp --update` (pulls, re-runs install.sh, then updates omp itself).
