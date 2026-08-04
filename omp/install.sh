#!/usr/bin/env bash
# Install/sync the omp harness dotfiles into this machine.
# Idempotent: safe to re-run. Existing real files are backed up once to *.pre-dotfiles.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"

link() { # link <target> <linkpath>
  local target="$1" path="$2"
  mkdir -p "$(dirname "$path")"
  if [ -e "$path" ] && [ ! -L "$path" ]; then
    cp "$path" "$path.pre-dotfiles"
    echo "backed up $path -> $path.pre-dotfiles"
  fi
  ln -sfn "$target" "$path"
}

# --- config files (symlinked: edits via `omp config set` land in the repo) ---
link "$REPO/omp/agent/config.yml" "$AGENT/config.yml"
link "$REPO/omp/agent/AGENTS.md"  "$AGENT/AGENTS.md"
link "$REPO/omp/agent/RULES.md"   "$AGENT/RULES.md"
for s in "$REPO"/omp/agent/skills/*; do
  [ -e "$s" ] || continue
  link "$s" "$AGENT/skills/$(basename "$s")"
done
link "$REPO/ponytail/config.json" "$HOME/.config/ponytail/config.json"

# --- plugins (idempotent: add/install only when absent) ---------------------
command -v omp >/dev/null 2>&1 || { echo "omp not on PATH — install omp first"; exit 1; }
omp plugin marketplace list | grep -q nszceta  || omp plugin marketplace add https://github.com/nszceta/omp-sub-burndown-indicator.git
omp plugin marketplace list | grep -q ponytail || omp plugin marketplace add DietrichGebert/ponytail
omp plugin list | grep -q omp-sub-burndown-indicator || omp plugin install omp-sub-burndown-indicator@nszceta
omp plugin list | grep -q 'ponytail@ponytail' || omp plugin install ponytail@ponytail

echo "--- installed plugins:"
omp plugin list
