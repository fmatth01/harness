# LangChain & LangGraph: what they are, run locally

This document explains two popular Python libraries for building programs that use large language models (LLMs — the AI models behind chatbots), how to run a small "agent" locally on this Mac with no API key, and how to connect that agent to omp (the agent harness that runs in your terminal). All version numbers and facts below were verified on 2026-08-08.

---

## 1. LangChain vs LangGraph: what they are now

Before the two libraries, one term: an **LLM** (large language model) is a program that predicts text — it is what powers chat. On its own an LLM only completes text; a **framework** is a toolbox of code that helps you build real applications around it (glue for models, tools, memory).

The ecosystem split into two layers in 2025, when both hit their 1.0 releases (both on 2025-10-17):

**LangChain 1.3.14** (MIT license) is the *high-level framework*: the batteries-included layer. It provides:

- **Model integrations** — adapters that let one line of code talk to many different LLMs, packaged as separate installs: `langchain-openai` 1.4.2 for OpenAI-compatible APIs, `langchain-ollama` 1.1.0 for local models served by Ollama.
- **Tools** — functions you hand the LLM so it can do things beyond text (look up a file, run a calculation, call an API). The LLM *calls* a tool by name with arguments, your code executes it, and the result is fed back.
- **Prompts** — reusable templates for the text you send the model.
- **Prebuilt agents** — ready-made "reason + act" loops that decide when to call tools; these are **built on LangGraph** underneath.

**LangGraph 1.2.10** (MIT license) is the *stateful graph orchestration* engine: the low-level layer that LangChain's agents are built on. A **graph** here is a network of steps; **stateful** means the graph carries a shared memory (the **state**) from step to step. It provides:

- **StateGraph** — the core abstraction: **nodes** (steps of work, e.g. "ask the model" or "run a tool") connected by **edges** (transitions), with **conditional routing** (edges that pick the next node based on the current state — e.g. "call a tool if the model asked for one, otherwise finish").
- **Functional API** — a lighter, function-based way to write the same graphs using `@entrypoint` / `@task` decorators (markers that turn plain functions into graph steps) instead of the node/edge class style.
- **Checkpoints** — snapshots of the graph's state at each step, so a run can be paused and resumed, or replayed.
- **Streaming** — emitting tokens (pieces of text) as the model generates them, instead of waiting for the full answer.
- **HITL** — "human-in-the-loop": the graph can pause and ask a person for input before continuing.
- **Persistence** — saving checkpoints to a database (SQLite or Postgres), so conversations survive restarts.
- **Store** — a separate long-term memory for facts that outlive any single conversation.
- **Multi-agent** — orchestrating several agents (each its own graph or loop) that hand work to each other.

Two important properties: LangGraph is **model-agnostic** (it does not care which LLM you use) and it is **usable without LangChain** (you can build graphs with plain model calls and skip the high-level layer entirely).

One naming change to know: **"LangGraph Platform" has been rebranded to LangSmith Deployment** — the hosted service that runs LangGraph apps in the cloud. Pricing: the dev tier is $0; the Plus tier is $39/seat and includes one free "Serverless Small" deployment.

---

## 2. Local quickstart (no API key)

This recipe runs a tiny "calculator agent" entirely on this Mac, using the Ollama local runtime and the small `qwen3:8b` model — no cloud account, no API key, no money.

First, terms: **uv** is a fast Python package manager (like `pip` on steroids); a **venv** (virtual environment) is an isolated folder for a project's Python packages so they never clash with other projects. **ChatOllama** is the LangChain integration that talks to Ollama's local API. **temperature** is a model setting for randomness: 0 means "always the most likely answer" — right for a calculator. **bind_tools** hands the model the list of tools it may call. **MessagesState** is LangGraph's built-in state shape: a list of chat messages (human, AI, tool) that grows as the conversation proceeds.

Set up the project:

```bash
mkdir ~/langgraph-lab && cd ~/langgraph-lab
uv venv --python 3.13
uv pip install "langchain[ollama]" langgraph
```

(The `langchain[ollama]` extra pulls in `langchain-ollama`; Python 3.13 is used because it is inside the verified 3.10–3.13 window.)

The agent is a graph with three parts: an `llm_call` node that asks the model, a `tools` node that executes the calculator tool, and a `should_continue` conditional edge that routes back to the model when a tool was called, or to END (finish) when the model is done. A **tool call** is the model saying "run `add` with these arguments" instead of answering directly — your code runs the real function and hands the result back, which is how an LLM (which cannot do arithmetic reliably) still gets the exact answer 7.

Write this file as `agent.py`:

```python
# agent.py — a tiny "calculator" agent built with LangGraph
from langchain_core.messages import HumanMessage
from langchain_core.tools import tool
from langchain_ollama import ChatOllama
from langgraph.graph import END, START, MessagesState, StateGraph
from langgraph.prebuilt import ToolNode


@tool
def add(a: int, b: int) -> int:
    """Add two integers and return the sum."""
    return a + b


llm = ChatOllama(model="qwen3:8b", temperature=0).bind_tools([add])


def llm_call(state: MessagesState) -> dict:
    """Ask the model to answer or to request a tool call."""
    return {"messages": [llm.invoke(state["messages"])]}


def should_continue(state: MessagesState) -> str:
    """Route to the tools node if the model called a tool, else finish."""
    last = state["messages"][-1]
    return "tools" if last.tool_calls else END


builder = StateGraph(MessagesState)
builder.add_node("llm_call", llm_call)
builder.add_node("tools", ToolNode([add]))  # runs tool_calls -> ToolMessage
builder.add_edge(START, "llm_call")
builder.add_conditional_edges("llm_call", should_continue, {"tools": "tools", END: END})
builder.add_edge("tools", "llm_call")

agent = builder.compile()

result = agent.invoke({"messages": [HumanMessage("Add 3 and 4.")]})
for msg in result["messages"]:
    print(f"{msg.type}: {msg.content}")
```

Run it (Ollama must be running with `qwen3:8b` pulled):

```bash
uv run agent.py
```

What you should see: an `ai` message with a tool call, a `tool` message containing `7`, and a final `ai` message answering `7` — the tool call happens first, then the answer.

---

## 3. Serving options

**Serving** means running your graph behind a network API (an interface other programs call over HTTP) so external clients can use it. The key compatibility question is whether the server speaks the **OpenAI wire format** — the JSON request/response shape (`/v1/chat/completions`, `/v1/models`) that most client tools, including omp, speak natively. A server with **no `/v1` OpenAI endpoints** requires an adapter in between.

| Option | What it is | License | OpenAI /v1 endpoint? | Verdict |
|---|---|---|---|---|
| `langgraph dev` / `langgraph up` (langgraph-cli 0.4.31 + langgraph-api 0.12.1) | The official local dev server: a REST API with **assistants**, **threads**, and **runs** (the Agent Server API) plus the Studio UI (a visual debugging interface) | Elastic-2.0 | **NO** — no `/v1` OpenAI endpoints (verified in the OpenAPI spec) | great for development, not directly consumable by omp |
| LangSmith Deployment (cloud or self-hosted) | The hosted/rebranded platform service (see §1) | — | **No OpenAI wire** — same Agent Server API as local | for production hosting, still needs an adapter for omp |
| LangServe 0.3.3 | LangChain's earlier serving framework | — | — | **ARCHIVED in 2026 — avoid**; use LangGraph's tooling instead |
| Custom FastAPI wrapper | A small hand-written HTTP server in front of your compiled graph | any (yours) | **Yes** — it *is* the OpenAI endpoint | **recommended for omp**; ~100 lines, `thread_id` → `configurable`, see §4 |
| `langgraph_openai_serve` 0.4.0 | Community-built adapter exposing an OpenAI-compatible layer over LangGraph | community | Yes | exists, but community maturity is **unverified** |
| liteLLM `langgraph` provider | liteLLM (a popular LLM gateway) translates OpenAI-format requests into the Agent Server API | — | Yes (via liteLLM) | solid if you already run liteLLM |

The takeaway: the official LangGraph servers do **not** expose the OpenAI wire format — that fact was verified directly in their OpenAPI specification. To connect a LangGraph agent to an OpenAI-speaking client you need one of the adapter rows above.

---

## 4. Integration patterns with an OpenAI-compatible host

An **OpenAI-compatible host** is any program that accepts the OpenAI chat-completions API shape — omp is one, and it can be pointed at any server that speaks that format. Four ways to put a LangGraph agent behind such a host:

1. **FastAPI wrapper in front of the compiled graph** — write a tiny server with two routes: `POST /v1/chat/completions` (translate incoming OpenAI messages into LangGraph input, run `agent.invoke`, translate the result back) and `GET /v1/models` (advertise the agent). Map the client's `thread_id` to LangGraph's `configurable` so each conversation keeps its own thread state. **This is the pattern chosen for this project** (steps C2/C4): ~100 lines, no extra services, works with omp's non-streaming path out of the box.
2. **liteLLM in front of the Agent Server** — keep the official `langgraph` server and let liteLLM translate between OpenAI format and the Agent Server API. More moving parts, useful if you already use liteLLM.
3. **langgraph-sdk / RemoteGraph for the native LangGraph protocol** — speak LangGraph's own protocol directly to a remote graph. Clean inside the LangGraph world, but omp would need a custom provider to understand that protocol.
4. **In-process import** — import the compiled graph straight into your host's Python process, no HTTP at all. Only works when the host runs Python (omp does not).

One more flexibility note: a LangGraph agent can call local models **both ways** — through `ChatOllama` (as in §2), or through `ChatOpenAI(base_url=…)` pointed at any local OpenAI-compatible server. Either way it is the *same endpoint* omp itself uses, so the model layer is shared and consistent.

---

## 5. Versions and security

Verified versions (2026-08-08):

| Package | Version | Notes |
|---|---|---|
| langchain | 1.3.14 | MIT; 1.0 since 2025-10-17 |
| langgraph | 1.2.10 | MIT; 1.0 since 2025-10-17 |
| langchain-openai | 1.4.2 | OpenAI-compatible integrations |
| langchain-ollama | 1.1.0 | Ollama integration |
| langgraph-cli | 0.4.31 | CLI for the dev server (§3) |
| langgraph-api | 0.12.1 | Elastic-2.0 |
| langgraph-sdk | 0.4.2 | client library for the Agent Server API |
| langserve | 0.3.3 | **archived** — do not start new projects on it |

**Security note — keep these updated:** langchain **<1.3.9** carries CVE-2026-55443 (a path traversal vulnerability, i.e. code that can read files outside its intended directory), and langgraph **<1.0.10** carries CVE-2026-28277 (a checkpoint deserialization vulnerability, i.e. malicious saved state that can execute code when loaded). Stay at or above those versions.

---

## TL;DR

LangChain = the batteries-included framework (model integrations, tools, prompts, prebuilt agents); LangGraph = the graph engine underneath it (stateful nodes/edges, checkpoints, streaming, memory). They are model-agnostic and usable together or separately. On this Mac you can run a local calculator agent with `ChatOllama(model="qwen3:8b")` — no API key — and serve it to omp through a tiny OpenAI-compatible FastAPI wrapper (~100 lines, `/v1/chat/completions` + `/v1/models`), because the official LangGraph server has no OpenAI wire endpoint.
