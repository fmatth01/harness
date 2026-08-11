#!/usr/bin/env bash
# OPT-IN: download the recommended local models for Ollama.
# Big (~59GB total) — run this only when you actually want the models.
# Skips models that are already present (ollama pull is idempotent).
set -euo pipefail

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama not found — install it first: brew install ollama && brew services start ollama"
  exit 1
fi

ollama pull gpt-oss:20b      # primary on-demand model     (12.1GB Q4 MoE)
ollama pull qwen3:8b         # fast background model        (4.7GB)
ollama pull qwen3-coder:30b  # coding MoE (trial pick)     (18.6GB Q4)
ollama pull qwen3.5:35b      # 35B-A3B MoE (trial pick)    (23.9GB Q4)
