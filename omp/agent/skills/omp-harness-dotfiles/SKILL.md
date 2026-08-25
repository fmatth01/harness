---
name: omp-harness-dotfiles
description: "Set up or transfer an omp harness setup between machines via a dotfiles repo: what to mirror from ~/.omp/agent, what to exclude, and the idempotent symlink+plugin install pattern."
---

# OMP Harness Dotfiles Transfer

Procedure for making an omp harness setup (config + context + skills + plugins) portable between machines. Artifact pattern proven on macOS (Darwin, BSD ln): `~/dotfiles/` repo with `omp/install.sh`.

## What to mirror (portable)
- `~/.omp/agent/config.yml` — ALL settings (the whole preference file; may change often — re-read before copying, never assume contents)
- `~/.omp/agent/AGENTS.md`, `RULES.md`, `SYSTEM.md`, `TITLE_SYSTEM.md` (only those that exist)
- `~/.omp/agent/keybindings.yml`, `models.yml` (only if present)
- `~/.omp/agent/skills/<name>/` (user skills; check for stray entries — a 0B file or symlink may be an unrelated skill the user wants excluded; ASK)
- `~/.omp/agent/rules/<file>` (same symlink pattern as skills)
- Plugin config like `~/.config/ponytail/config.json`

## Never copy (machine-local)
- `agent.db*`, `history.db*`, `models.db*`, `*.lock`, `secret-placeholder.key`, `install-id`
- `sessions/`, `terminal-sessions/`, `blobs/`, `logs/`, `run/`, `managed-skills/`
- Managed skills are machine-local by design — to make one portable, copy its `SKILL.md` into `omp/agent/skills/<name>/` in this repo and re-run `install.sh` (this skill itself was promoted that way).
- `marketplaces.json` + `plugins/` — re-run commands instead (paths inside are absolute/machine-specific)
- Credentials: re-login or `OMP_AUTH_BROKER_URL`/`OMP_AUTH_BROKER_TOKEN` on the new machine

## install.sh pattern (idempotent)
- `link()` helper: `mkdir -p dirname`; if path exists and is NOT a symlink → back up: remove stale `$path.pre-dotfiles` then `mv "$path" "$path.pre-dotfiles"` (mv handles files AND dirs; `cp` does not without -R); then `ln -sfn "$target" "$path"`.
- GOTCHA (BSD/macOS ln): `ln -sfn` with an existing REAL directory as destination creates the link INSIDE it instead of replacing it. The mv-aside step above is what makes dirs link correctly — never ln over a still-existing real dir.
- Plugins idempotent: `omp plugin marketplace list | grep -q <name> || omp plugin marketplace add <source>`; same pattern with `omp plugin install name@marketplace`.
- Run it once on the source machine as a smoke test; verify with `readlink`/`stat -f '%HT'` (symlink, not dir) and `omp config get <key>` through the link.
- Symlinked `config.yml` means `omp config set` writes land in the repo — git diff is the change history. If a write ever replaces the file (rename-based save), re-run install.sh to re-link.
- Note: `omp config set` does NOT accept record subkeys like `modelRoles.default` — edit YAML or set the full record as JSON (records/arrays replace wholesale).

## New machine flow
Install omp → `git clone <repo> ~/dotfiles` → `~/dotfiles/omp/install.sh` (backs up existing files, symlinks, installs plugins) → re-auth (login or broker). Sessions never transfer; use `/export`/`/share` for transcripts.
## Adding new skills/rules (convention)
Create the skill dir under `omp/agent/skills/<name>/` in this repo (rules under `omp/agent/rules/`), then run `~/harness/omp/install.sh` to link it. install.sh emits `WARN:` lines for anything in `~/.omp/agent/{skills,rules}` that is not mirrored from the repo, so drift shows up on every run.
