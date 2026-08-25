#!/usr/bin/env bash
# OPT-IN: download a local model for Ollama.
# Big download — run this only when you actually want the model.
# Skips models that are already present (ollama pull is idempotent).
set -euo pipefail

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama not found — install it first: brew install ollama && brew services start ollama"
  exit 1
fi

ollama pull hf.co/Qwen/Qwen3.8-27B
