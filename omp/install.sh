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
    if [ -e "$path.pre-dotfiles" ]; then rm -rf "$path.pre-dotfiles"; fi
    mv "$path" "$path.pre-dotfiles"
    echo "moved $path -> $path.pre-dotfiles"
  fi
  ln -sfn "$target" "$path"
}

# --- config files (symlinked: edits via `omp config set` land in the repo) ---
link "$REPO/omp/agent/config.yml" "$AGENT/config.yml"
link "$REPO/omp/agent/AGENTS.md"  "$AGENT/AGENTS.md"
link "$REPO/omp/agent/RULES.md"   "$AGENT/RULES.md"
link "$REPO/omp/agent/models.yml" "$AGENT/models.yml"
for s in "$REPO"/omp/agent/skills/*; do
  [ -e "$s" ] || continue
  link "$s" "$AGENT/skills/$(basename "$s")"
done
# drop links to skills that no longer exist in the repo (ours, dangling only)
for s in "$AGENT"/skills/*; do
  [ -L "$s" ] || continue
  case "$(readlink "$s")" in
    "$REPO"/*)
      [ -e "$s" ] || { rm -f "$s"; echo "removed stale skill link $s"; }
      ;;
  esac
done
link "$REPO/ponytail/config.json" "$HOME/.config/ponytail/config.json"

# --- fonts (nerd glyphs for the status line; idempotent) --------------------
FONT_CASK=font-jetbrains-mono-nerd-font
if command -v brew >/dev/null 2>&1; then
  if ! brew list --cask "$FONT_CASK" >/dev/null 2>&1; then
    brew install --cask "$FONT_CASK"
  fi
  # replaced font-symbols-only-nerd-font — icons now come from the family
  brew list --cask font-symbols-only-nerd-font >/dev/null 2>&1 && brew uninstall --cask font-symbols-only-nerd-font
else
  echo "brew not found — skipping nerd font install; grab JetBrains Mono Nerd Font from https://www.nerdfonts.com/font-downloads"
fi

# --- tmux (session manager; idempotent) -------------------------------------
if command -v brew >/dev/null 2>&1; then
  if ! command -v tmux >/dev/null 2>&1; then
    brew install tmux
  elif ! brew list --versions tmux | grep -q ' 3\.7'; then
    brew upgrade tmux
  fi
fi
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
link "$REPO/tmux/tmux.conf" "$HOME/.tmux.conf"

# --- plugins (idempotent: add/install only when absent) ---------------------
command -v omp >/dev/null 2>&1 || { echo "omp not on PATH — install omp first"; exit 1; }
omp plugin marketplace list | grep -q nszceta  || omp plugin marketplace add https://github.com/nszceta/omp-sub-burndown-indicator.git
omp plugin marketplace list | grep -q ponytail || omp plugin marketplace add DietrichGebert/ponytail
omp plugin list | grep -q omp-sub-burndown-indicator || omp plugin install omp-sub-burndown-indicator@nszceta
omp plugin list | grep -q 'ponytail@ponytail' || omp plugin install ponytail@ponytail

echo "--- installed plugins:"
omp plugin list

# --- `omp --update` hook (idempotent: regenerates the marked rc block) ------
rc=""
case "${SHELL##*/}" in
  zsh)  rc="$HOME/.zshrc" ;;
  bash) rc="$HOME/.bashrc" ;;
esac
if [ -n "$rc" ]; then
  touch "$rc"
  tmp="$(mktemp)"
  awk -v b='# >>> omp-harness-update >>>' -v e='# <<< omp-harness-update <<<' \
    '$0==b{f=1} !f{print} $0==e{f=0}' "$rc" > "$tmp"
  cat >> "$tmp" <<EOF

# >>> omp-harness-update >>>
# Managed by $REPO/omp/install.sh — re-run install.sh to regenerate.
omp() {
  case "\$1" in
    --update|update) "$REPO/omp/update.sh" ;;
    *) command omp "\$@" ;;
  esac
}
# <<< omp-harness-update <<<
EOF
  mv "$tmp" "$rc"
  echo "installed omp() update hook in $rc"

  # --- editor env (set once, only when unset) ---
  if ! grep -qE '^(export )?(VISUAL|EDITOR)=' "$rc" 2>/dev/null; then
    if command -v code >/dev/null 2>&1; then ed="code --wait"; else ed="vim"; fi
    printf "\nexport VISUAL='%s'\nexport EDITOR='%s'\n" "$ed" "$ed" >> "$rc"
    echo "set VISUAL/EDITOR=$ed in $rc"
  fi
else
  echo "unsupported shell ${SHELL##*/} — omp --update alias not installed"
fi

# --- local LLM models (opt-in on purpose: ~59GB) ----------------------------
echo "Local LLM models are NOT downloaded automatically. When you want them, run:"
echo "  $REPO/omp/pull-models.sh"
