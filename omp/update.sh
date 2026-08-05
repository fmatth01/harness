#!/usr/bin/env bash
# `omp --update` implementation: sync local changes with main, pull, re-run the
# installer, then update omp itself. Invoked by the omp() shell function
# install.sh installs.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1) commit local edits (rules/config written through the symlinks) so they can sync
if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "auto-sync: local changes before update"
fi

# 2) merge local commits with origin, then push if we're ahead
git -C "$REPO" pull --rebase --autostash origin main
if [ "$(git -C "$REPO" rev-list --count origin/main..HEAD)" -gt 0 ]; then
  git -C "$REPO" push origin main
  echo "pushed local changes to origin/main"
fi

# 3) update as usual
"$REPO/omp/install.sh"
command omp update
