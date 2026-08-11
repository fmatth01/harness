# Local LLMs on this Mac (32GB M1 Pro)

This document is the research behind running open-weight LLMs (large language models) locally on
this machine: an Apple M1 Pro with 32GB of memory. "Locally" means the model runs on this computer's
own chips — no internet, no API fees, and no text leaving the machine. The document covers what you
need to understand first, which models fit, which ones do not, which serving runtime to use, the
pitfalls, and how omp (the agent harness on this machine) consumes local models.

All tables are transcribed from a research pass dated 2026-08-08 through 2026-08-10. Every number
carries a provenance tag that says where it came from; the tags are explained at the end of
section 1.

## 1. First, three ideas: quantization, MoE, tok/s

**Quantization.** An LLM is a large file of numbers called *weights* — the values the model learned
during training, which it uses to predict the next word. Normally each weight is stored as a 16-bit
or 32-bit number: very precise, but heavy. *Quantization* stores the weights with fewer bits — 8, 4,
or even 2 — which shrinks the file and the memory it needs, at a small cost in quality. Think of it
like compressing a photo: a 4-bit quantized model is a high-quality JPEG, slightly softer than the
original, usually fine in practice. The most common format, Q4_K_M, needs about 0.6GB per billion
parameters ("0.6GB/B"). On a 32GB Mac, quantization is the difference between a model fitting in
memory and not: the practical ceiling is about 26GB, because macOS and the Metal GPU keep roughly
22–30% of the RAM busy.

**MoE (Mixture of Experts).** Most models are *dense*: every token (word fragment) activates all of
their parameters. MoE models split their weights into many small "expert" sub-networks, and for each
token a router wakes up only a few experts. That is why they have two parameter counts: *total*
(drives the file size and memory) and *active* (drives the compute per token). "35B/3B MoE" means 35
billion total parameters but only 3 billion active per token. The whole file must still sit in RAM,
but each token is cheap to compute, so MoE models generate text much faster. That suits a Mac: the
M1 Pro has plenty of memory but a modest GPU, so fast-decode MoE models punch above their weight
here.

**tok/s (tokens per second).** Models read and write text in *tokens* — roughly three-quarters of a
word in English ("the cat" is about three tokens). Generation speed is measured in tokens per second
(tok/s). Feel: below 5 tok/s is waiting; 10–15 tok/s is comfortable chat; 20+ tok/s feels fast and
suits agentic or background work. There are two speeds: *prefill* (reading your prompt; fast, tens
of tok/s) and *generation* (writing the answer; this is the number that matters). The tables below
are generation speeds unless noted.

**Provenance tags** used in the tables: `[M1P]` = measured on an M1 Pro; `[M1 Max]`, `[M2 Pro]`,
`[M3 Max]` = measured on that chip; `[INF]` = inferred for the M1 Pro from a measurement on similar
hardware (a reasonable estimate, not directly measured); `[est]` = estimate; `[UNVERIFIED]` = not
yet verified. Benchmark names: MMLU / MMLU-Pro = general knowledge and reasoning tests; GPQA(-D) =
graduate-level science questions; SWE-bench (V) = fixing real GitHub issues; AIME = math olympiad
problems; MATH(-500) = math problems; HumanEval(+) = code generation; LCB = LiveCodeBench (coding).
Higher is better on all of them.

## 2. The fit-model field (what actually runs on 32GB)

The budget: **model + KV cache ≈ 20–24GB; Q4_K_M ≈ 0.6GB/B**. The *KV cache* is the memory the
model needs to remember the conversation so far; it grows with the context length, so the numbers
below are file sizes, and a long conversation adds a few GB on top. Compare each row's GB against
the practical ceiling of ~26GB.

| Model | Params (total/active) | Ctx | License | Quant + GB | Benchmarks | tok/s (M1 Pro-class, source) | Notes |
|---|---|---|---|---|---|---|---|
| Qwen3.5-27B | 27B dense, hybrid, vision | 256K→1M | Apache-2.0 | Q4_K_M ≈16.5GB | MMLU-Pro 86.1, GPQA-D 85.5, SWE-bench V 72.4 | 15.5 gen / 67.4 prefill [M1 Max oMLX 4-bit]; M1 Pro ≈8–11 [INF] | best dense quality-per-GB; thinking modes |
| Qwen3.5-35B-A3B | 35B/3B MoE | 256K→1M | Apache-2.0 | Q4 ≈20.5GB TIGHT; 3-bit ≈17GB | MMLU-Pro 85.3, GPQA-D 84.2, SWE-bench V 69.2 | 61.2 [M1 Max 64GB MLX]; M1 Pro ≈25–35 [INF] | fast decode; keep ctx modest at Q4 |
| Qwen3-30B-A3B | 30B/3B MoE | 128K | Apache-2.0 | Q4_K_M ≈18.5GB | MMLU 81.4, AIME'24 80.4, LCB v5 62.6 | 13 [M1P 16GB Q6 paged]; in-RAM ≈25–35 [INF] | value MoE pick |
| Qwen3-32B | 32B dense | 128K | Apache-2.0 | Q4_K_M ≈19.4GB | AIME'24 79.5, LCB v5 62.7 | M1 Pro ≈6–8 [INF] | bandwidth-bound; superseded by Qwen3.5-27B |
| Gemma 4 26B-A4B | 26B/3.8B MoE | 128K–256K | Apache-2.0 | Q4_K_M ≈15.5GB | AIME'26 ≈89, LCB v6 ≈80 (vendor/community) | M1 Pro ≈20–25 [INF] | newest fit MoE; multimodal |
| Gemma 4 31B | 31B dense | 128K–256K | Apache-2.0 | Q4_K_M ≈18.5GB | #3 open model on Arena | M1 Pro ≈6–8 [INF] | slow decode |
| Mistral Small 3.2 24B | 24B dense, vision | 128K | Apache-2.0 | Q4_K_M ≈14.7GB | MMLU 80.5, MATH 69.4, HumanEval+ 92.9 | M1 Pro ≈10–14 [INF] | good function calling |
| GPT-OSS-20b | 21B/3.6B MoE | 128K | Apache-2.0 | Q4_K_M ≈12.1GB | MMLU 84.0, GPQA-D 66.0, SWE-bench V 53.2 | ~24 [M2 Pro 32GB LM Studio]; M1 Pro ≈22–25 [INF] | fast; the primary install |
| Phi-4 14B | 14B dense | 16K | MIT | Q4_K_M ≈8.9GB | MMLU 84.8, GPQA 56.1, MATH 80.4 | M1 Pro ≈15–20 [INF] | 16K ctx limits agents |
| DeepSeek-R1-Distill-Qwen-32B | 32B dense | 128K | MIT | Q4_K_M ≈19.9GB TIGHT | AIME'24 72.6, MATH-500 94.3, GPQA 65.2 | M1 Pro ≈6–8 [INF] | strong reasoning, slow |
| Qwen 4 Coder 32B-A3B | 32B/3B MoE | 256K | Apache-2.0 | Q4 ≈19GB | [UNVERIFIED] | M1 Pro ≈25–35 [INF] | newest coding MoE |
| Small class: Gemma 4 E4B ≈3GB (42 est), SmolLM3-3B ≈2.2GB (65 est), Llama 3.1 8B Q4/Q5 = 19–22 [M1P measured, Ollama] | — | — | — | — | — | — | for the smol/tiny role |

**DO-NOT-FIT note:** models that exceed the 20–24GB budget even at Q4 are collected in section 4 —
they do not run on this Mac.

**How to read this table.** The *Params* column tells you the shape: "27B dense" means all 27B
parameters run for every token; "35B/3B MoE" means 35B sit in the file (memory) but only 3B are
active per token (speed). *Ctx* is the context window — how many tokens of conversation the model
can remember (128K = 128,000). *Quant + GB* is the file size at Q4_K_M; compare it to the ~26GB
practical ceiling, and treat "TIGHT" as fitting with little room left for a long context. The tok/s
column is generation speed on M1 Pro-class hardware, tagged with its source; `[INF]` entries are
inferred, not measured on this exact chip. The last row is the *small class*: tiny models for the
"background/smol" role, where Llama 3.1 8B at Q4/Q5 was measured at 19–22 tok/s on an M1 Pro with
Ollama.

## 3. The stretch tier (big models squeezed onto 32GB)

These models fit 32GB only through heavy 2-bit quantization (Q2/IQ2 — the "highly compressed"
formats) or by offloading parts of the model to disk. This is the **tinkering tier, not the
daily-driver tier**: you can boot them to see what they do, but the quality loss and low speed make
them poor for real work. The numbers below were verified 2026-08-10, with exact GGUF file sizes
taken from HuggingFace file listings. The practical ceiling is ≈26GB, because macOS plus the Metal
GPU working set uses about 70–78% of the 32GB.

- **Llama 3.3 70B** and **DeepSeek-R1-Distill-Llama-70B** (70.6B dense): quant sizes are IQ2_XXS
  19.4GB, IQ2_M 24.3GB, Q2_K 26.4GB, IQ3_XXS 27.7GB — these fit. Q3_K_S 30.9GB fits as a file but
  leaves zero headroom — no. Speed [est, no direct Apple Q2 report exists]: Q2_K ≈4–5 tok/s, IQ2_XXS
  ≈2–3 tok/s on the M1 Pro (anchor: 70B Q4_K_M = 4.09 tok/s on M1 Max, 7.53 on M3 Max — llama.cpp
  bench repo). Quality: Q2_K +68.7% ppl, IQ2_M +72.4%, IQ2_XXS +135.6% vs FP16 — tinkering tier;
  R1-distill reasoning breaks worse at Q2 (broken CoT chains). **IQ2_M has NO Metal kernel —
  CPU-only on Apple, avoid.** (ppl = perplexity, a quality-loss measure; higher is worse. FP16 =
  full-precision baseline. CoT = chain-of-thought, the model's step-by-step reasoning. Metal =
  Apple's GPU interface; "no Metal kernel" means the format cannot use the GPU and runs on the CPU,
  which is 5–20× slower.)
- **Llama 4 Scout** (109B-A17B MoE): the smallest quant is IQ1_S at 32.5GB (+248.5% ppl — unusable);
  NO at any Q2-class.
- **GLM-4.5-Air** (106B-A12B MoE — correction: "GLM-5.2-Air" does not exist; GLM-5.2 is the 753.9B
  giant only): the smallest quant is TQ1_0 at 38.3GB — NO. Disk-streamed Q4_K_M ≈0.75 tok/s (RTX
  4080 report, llama.cpp #23324) — last resort.
- **MiniMax M2** (229B): smallest TQ1_0 56.4GB — NO. **Kimi K2.5** (1T): TQ1_0 239.5GB — NO.
  **Qwen3.5-122B-A10B**: smallest IQ1_M 38.7GB — NO.
- **Offload tier (llama.cpp MoE expert disk-paging, discussion #23324)**: Qwen3-30B-A3B Q6_K
  (25.1GB) paged = **13 tok/s measured on M1 Pro 16GB** with `--moe-n-slots 80 --moe-n-layers 48
  --no-mmap --no-warmup -ub 10`; exact inference, Q6_K +0.47% ppl; the same file vanilla in-RAM on
  this 32GB machine [est] 35–45 tok/s. MoE streaming of 70GB+ models ≈0.75 tok/s — only as a last
  resort. (Offloading = the runtime keeps some experts on disk and loads them on demand, trading
  speed for memory.)
- **Method note**: Q2_K ≈0.37GB/B, IQ2_XXS ≈0.27, IQ1_S ≈0.22, TQ1_0 ≈0.17; MoE quants price ALL
  experts (Scout 39.6/109 ✓). In plain words: the smaller the quant, the less memory per billion
  parameters, but the more quality you lose; and for MoE models you pay for every expert in the
  file, not just the active ones.

Bottom line: at this tier you trade most of the model's quality and speed for the chance to see it
run at all. If you want something that works, use the models in section 2.

## 4. The DO-NOT-FIT frontier

**Why these do not fit:** at Q4_K_M a model needs ≈0.6GB per billion parameters. Anything over
roughly 43B parameters bursts the ~26GB practical ceiling, and these are all far bigger — their Q4
files range from 59GB to over a terabyte. Do not try to download them on this machine. Each entry
shows the Q4-class file size in parentheses.

- **DeepSeek V4-Pro (1.6T, ~865GB) / V4-Flash (284B, ~160GB)** — flagship reasoning models; the
  Pro is over 30× the machine's whole RAM, quantized.
- **DeepSeek R1/V3.2 (671B, ~400GB)** — the famous reasoning series, still ~400GB at Q4.
- **Kimi K2.5 (1T, ~590GB), K3 (2.8T, ~1.6TB)** — trillion-parameter frontiers; K3 would need
  1.6TB of memory.
- **GLM-5.2 (753B, ~440GB), GLM-5.2-Air (106B, ~62GB)** — the GLM family's big dense models; even
  the "Air" is more than twice the machine's RAM. (Note: section 3 corrects this — "GLM-5.2-Air"
  does not exist as such; the 106B model is GLM-4.5-Air. The entry is kept here as recorded.)
- **Qwen3.5-397B-A17B (~233GB), 122B-A10B (~72GB), Qwen3-235B (~133GB)** — Qwen's top MoE and
  dense sizes; even the 122B needs 72GB.
- **MiniMax M2 (~135GB), M3 (~250GB)** — 100GB+ dense/MoE, no path onto 32GB.
- **Llama 4 Scout (~64GB), Maverick (~235GB)** — the Llama 4 family; Scout is MoE but its total
  size still defeats 32GB.
- **Mistral Large 3 (~400GB), Medium 3.5 (~75GB), Small 4 (~70GB)** — Mistral's big three, all far
  over budget.
- **GPT-OSS-120b (~69GB)** — the big sibling of the 20b model in section 2; 69GB is still way over.
- **Grok 4 Open (~59GB)** — the smallest file in this list, still 59GB > 32GB.

**Also unverified/too-new-to-score: Llama 5, Gemma 4.5, Phi-5, Mistral Small 4, Qwen 4 dense,
Nemotron Cascade 2, OLMo 3, Granite 4.1.** These may become interesting, but there are no
trustworthy scores or quant info yet — re-check them later rather than guessing.

## 5. Runtimes: the software that serves models

A *runtime* is the program that loads the model file, runs it on the GPU, and exposes it to other
programs over HTTP on a local port. "OpenAI-compatible" means it speaks the same wire API that
OpenAI's cloud API speaks — which is exactly what omp understands, so any of these runtimes drops
into omp without a custom adapter.

| Runtime | Install | OpenAI-compatible | Apple Silicon speed | Maintenance/license | Fit |
|---|---|---|---|---|---|
| llama.cpp (llama-server) | `brew install llama.cpp` / llama.app | Yes /v1/* | Best GGUF; Metal first-class; MoE offload | very active, MIT | most control |
| Ollama | `brew install ollama` | Yes :11434/v1 (chat, tools, embeddings, Responses) | good; MLX engine preview v0.19+ ≈2× on ≥32GB | very active, MIT | easiest DX; omp auto-discovers |
| LM Studio | .dmg | Yes :1234 + Anthropic-compat | good (GGUF+MLX engines) | proprietary app, free tier | GUI path |
| MLX mlx-lm | `pip install mlx-lm` | Yes :8080 (tools/thinking) | fastest MoE/≤14B; long-ctx >30K slower | active, Apache-2.0 | max tok/s; manual server |
| Exo | pip/brew | Yes :52415 | MLX-based; multi-device clusters | active, Apache-2.0 | only for pooling 2+ Macs |

(GGUF = the standard quantized model file format used by llama.cpp and friends; MLX = Apple's
machine-learning framework; DX = developer experience, i.e. how pleasant it is to operate.)

### The evaluation

**Constraints.** M1 Pro 32GB; the host is the omp agent harness (needs OpenAI wire + tool-calling +
streaming); the user is a beginner at serving models; the models fill a background + on-demand
role; the runtime must be macOS-native and reproducible via `install.sh`.

**Candidates.** Ollama, llama.cpp, mlx-lm, LM Studio. Exo is reframed and excluded: it exists to
pool two or more Macs into one cluster, which is a different use case — this is a single machine —
so it is out of scope here.

**Axes (what we compared on).** tool-calling maturity for agents; tok/s on the fit-MoE sweet spot;
install/ops burden; omp zero-config discovery; model convenience.

**The concrete matrix.**

| Axis | Ollama | llama.cpp | mlx-lm | LM Studio |
|---|---|---|---|---|
| tool-calling | verified tools + Responses | verified | server has tools (less battle-tested) | SDK-level |
| tok/s | good; +MLX preview ≈2× | good | fastest (best on MoE / ≤14B; long-ctx >30K slower) | good (GUI overhead) |
| ops burden | brew service, `ollama pull` — least | manual server | manual server | install app, click |
| omp discovery | implicit keyless | implicit keyless | needs models.yml entry | implicit keyless |
| model convenience | first-class library | fetch GGUF yourself | fetch from HF yourself | GUI browse |

**Recommendation: Ollama.** It is the only candidate that is simultaneously: (1) zero-config in
omp, (2) tool-calling-verified, (3) brew-managed, and (4) gaining the MLX engine (preview v0.19+,
≈2× speed on ≥32GB machines). For a beginner on this harness, it is the one runtime where nothing
has to be configured by hand.

**When this recommendation would be wrong.**
- If a specific model you need is missing or broken in Ollama's library → use **llama.cpp**
  (GGUF-first-class, newest architecture support).
- If maximum tok/s becomes the goal for MoE-heavy workloads → use **mlx-lm**.
- If you want a GUI to browse and run models → use **LM Studio**.

## 6. Pitfalls and fixes

Each entry: if X happens, do Y.

1. **If a model is bigger than the free RAM** → macOS starts swapping to disk and speed collapses
   to 1–5 tok/s. Do: quantize to ≤24GB, and use the wired-limit knob (`sysctl
   iogpu.wired_limit_mb`) to cap how much RAM the GPU can pin.
2. **If inference is 5–20× slower than the tables say** → it is running on the CPU, not the GPU.
   Do: use Metal builds and check that the runtime log says `Metal: YES`.
3. **If you set the context length too large** → the KV cache runs out of memory and the process
   dies. Do: keep `-c 8192–16384` and use q8_0 KV (a compact format for the cache).
4. **If output is gibberish or tools break** → the wrong chat template is being applied. Do: use
   `--jinja` or per-model templates, and set `enable_thinking:false` for Qwen models when you want
   non-thinking mode.
5. **If Qwen output quality is poor** → the sampling parameters are off. Do: thinking mode — temp
   1.0, top_p 0.95, top_k 20, presence penalty 0; non-thinking — 0.7/1.5; coding — 0.6.
6. **If you offload MoE experts (n-cpu-moe or disk paging)** → expect 2–10× slower generation. Do:
   pick an MoE whose TOTAL Q4 file fits in RAM.
7. **If Ollama feels ~50% slower than raw llama.cpp on the same file** → that is wrapper overhead.
   Do: update Ollama and try the MLX engine preview.
8. **If gpt-oss MXFP4 runs slower than GGUF** → engine/quant mismatch. Do: prefer GGUF Q4_K_M for
   llama.cpp and MLX 4-bit for mlx-lm; test the same model in both formats and keep the faster one.
9. **If long contexts (>30K tokens) on MLX are ~50% slower** → do: use llama.cpp for long-context
   work.
10. **If the system feels sluggish or models will not load** → wired memory is too low. Do: raise
    the limit, close apps, and keep ≥8GB free.
11. **If a benchmark number looks off** → naive tok/s reading. Do: compare generation tok/s only,
    with the same quant, context, and engine.
12. **If a new architecture (Gated DeltaNet etc.) runs badly or not at all** → the runtime is
    stale. Do: update the runtime first; new architectures need new kernels.

## 7. How omp consumes local engines

omp ships with built-in *implicit* providers for the common local runtimes: `ollama` on port
11434, `llama.cpp` (llama-server) on port 8080, and `lm-studio` on port 1234. These are keyless —
no API key, no config entry, no registration. If a runtime is running on its default port, omp
auto-discovers it: `omp models find <name>` lists the model as e.g. `ollama/gpt-oss:20b`, and
selecting `/model` inside a chat session shows the local models next to the cloud ones.

Important: this track changes **no user config**. Your `modelRoles` and existing config are not
touched — the local engines appear alongside what is already configured, not instead of it. There
is nothing to edit for Ollama, llama.cpp, or LM Studio; only a manual runtime like mlx-lm would
need a `models.yml` provider entry.

## TL;DR

- **Runtime:** Ollama — brew-managed, zero-config in omp, verified tool-calling, MLX engine preview
  coming for speed.
- **Primary (on-demand) model:** `gpt-oss:20b` — 12.1GB Q4, fast MoE decode, ≈22–25 tok/s [INF].
- **Background/fast model:** `qwen3:8b`.
- **Fallback:** if `gpt-oss:20b` is missing from the Ollama library, pull `qwen3:30b-a3b` (18.5GB
  Q4) instead.
- Companion docs: `docs/tmux.md` (terminal setup) and `docs/langgraph.md` (LangGraph experiments).
