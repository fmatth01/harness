#!/usr/bin/env bash
# `omp --update` implementation: sync this repo, re-run the installer, then
# update omp itself. Invoked by the omp() shell function install.sh installs.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git -C "$REPO" pull --rebase --autostash
"$REPO/omp/install.sh"
command omp update
