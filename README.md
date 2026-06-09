# operation-Trismegistus

**A one-stop-shop harness dashboard for multi-agent coordination — the control plane where one human orchestrator runs a roster of AI agents in parallel, all observable in one place.**

---

## What it is

operation-Trismegistus is the **control plane / dashboard** for orchestrating multiple AI coding agents at once. Instead of babysitting one agent in one terminal, a human orchestrator speaks intent in natural language and the harness fans the work out across a roster of agents working in parallel — each sandboxed, each on its own task, all surfaced through a single living view of who is doing what, where, and why.

The vision is a **harness**: a thin coordination layer that sits on top of a sandboxed-agent runtime ([Warren](#how-it-works)) and turns it into a cockpit. Plans become parallel work. Tasks get dispatched, monitored, and merged. Goals, roles, configs, logs, and memories all live in one place. The orchestrator never types a raw API call or watches a wall of separate consoles — they drive the fleet from one seat.

> **Status note (grounding):** this is a working **pilot foundation**, not a finished product. The integration design, the HTTP control scripts, the project config, and a staged execution plan are all in place; Phase 0 and Phase 1 of the rollout are complete. See [Current status](#current-status) for exactly what exists today versus the broader vision.

---

## Capabilities

The dashboard is organized around the capability domains a human needs to coordinate a fleet of agents:

| Domain | What it covers |
| :--- | :--- |
| **Coordination** | One orchestrator, many agents — the harness keeps them from colliding and keeps the human in the loop. |
| **Orchestration** | Translate operator intent into dispatches, steers, and merges across the roster. |
| **Communication** | Natural-language intent in; plain-text state out. Mid-run steering messages reach a running agent. |
| **Plans** | Structured, decomposed plans (`.seeds/`) that become serialized, dependency-aware work. |
| **Tasks** | Each plan step is a scoped task dispatched to an agent, tracked from open → in-flight → merged. |
| **Goals** | The orchestrator sets the objective; the harness drives phases toward it with human gates at the boundaries. |
| **Projects** | Multiple repos registered as projects, each with its own config, branch policy, and roster. |
| **Logs** | Live event streams (NDJSON) from every run — stdout, state transitions, costs — captured and surfaced. |
| **Memories** | Durable project expertise and session handoffs persist across sessions, reaped back from agent runs. |
| **Roles** | Named agent roles (planner, sapling, pi, claude-code, …) map to the right runtime for each job. |
| **Configs** | Per-project `.warren/` config: quality gate, branch prefix, merge policy, interactive runtimes. |
| **Observation** | A single living state surface — done / in-flight / next / blockers / costs — without opening a UI. |
| **Parallel work** | Multiple agents (and multiple devices) working simultaneously, coordinated from one control plane. |
| **Long-running tasks** | Phase-level plan-runs that span many serial sub-tasks and survive interruption (idempotent resume). |
| **Tool use** | Agents run inside a real sandbox with full tool access (edit, shell, git) — scoped, not crippled. |
| **Shared state** | Plans, configs, memories, and status live in the repo as the shared substrate every agent reads. |
| **Active state** | What is running *right now* — which agent, which task, which PR — always queryable at a glance. |

---

## The multi-agent model

A single human **orchestrator** coordinates a roster of named agents. Each agent maps to a runtime role; the orchestrator assigns work, observes progress, and approves the gates.

| Agent | Role | Runtime |
| :--- | :--- | :--- |
| **K-bot-T1** | Planner | Warren `planner` agent |
| **K-bot-T2** | Builder | Warren `sapling` agent |
| **K-bot-T3** | Specialist | Warren `pi` agent |
| **LucraTitan** | Worker (second device) | Warren `claude-code` agent, on a separate device's account |
| **Orchestrator** | Human-in-command | **KevinGastelum** |

The roster is deliberately heterogeneous: planning, building, and specialist roles run as distinct agents, and a second device (LucraTitan) contributes its own `claude-code` worker — so the fleet spans roles *and* machines while still being driven from one dashboard.

---

## Current status

**Foundation in place. Phase 0 and Phase 1 complete.** This repo currently holds the **Warren pilot integration foundation**:

- **`docs/warren-integration/`** — the self-contained design package (`WARREN-PILOT-INTEGRATION.md`) and the completed **Phase 0 ground-truth report** (`PHASE-0-REPORT.md`). Phase 0 verified the live Warren instance end-to-end (version, endpoints, agent registry, plan-run support, event streaming, auth); Phase 1 (topology + registration) is done.
- **`scripts/wr-*.sh`** — HTTP API helpers for driving Warren (health, projects, agents, run, events, steer, cancel, refresh) at `http://localhost:8080`. The token auto-loads via `wr-env.sh`; it is never exported by hand.
- **`.warren/`** — this project's Warren config (quality gate, branch policy, **manual-merge / never auto-merge**, interactive runtimes) plus PR template and triggers (all cron triggers disabled for safety).
- **`.seeds/`** — a staged execution plan, **`pl-a703`** ("Pilot-layer artifacts / plan-run validator"): three serial child seeds that build the remaining pilot-layer artifacts *and* serve as the first end-to-end validation of Warren's plan-run coordinator and the phase-close review gate — dogfooding the harness on its own control repo.

This repo is registered with Warren as project **`prj_203c32jc0bqz`** (public). The next step is to execute `pl-a703`.

What is **not** built yet: the full live dashboard surface, the complete parallel-roster automation, and the broader capability set above are the **vision** this foundation is being built toward — not claims about what runs today.

---

## How it works

The harness follows a **local-pilot + Warren-workers + Codex-review** model:

- **Warren** is a self-hosted control plane for **sandboxed coding agents**. Workers run headless (`claude --prompt` inside a `bwrap` sandbox), get a scoped task, do real tool-using work, commit, and return their output as a **branch / PR** — never auto-merged. Warren's plan-run coordinator drives serial, dependency-aware execution server-side and resumes idempotently.
- **The local pilot** is the orchestrator's seat: it translates intent into Warren HTTP calls (via `scripts/wr-*.sh` / the SDK), dispatches and steers runs, streams their events, and maintains the living state surface. The operator never types a Warren command or watches a separate dashboard.
- **The Codex review gate** sits at phase boundaries: before a phase-closing merge, a non-author-biased reviewer (Codex) inspects the cumulative diff. The pilot **holds** the gate PR and merges only if the review is clean — the one merge that is never silent.

The result is a control plane where parallel, long-running, sandboxed agent work stays observable, steerable, and reviewable from a single seat.

---

## Safety

- Warren output is **always a branch/PR for human review** — never auto-merged. Treat agent output as untrusted until reviewed.
- Secrets never leave the box: the Warren API token and `.env` are never printed, committed, or pasted. A local guard hook (`.claude/hooks/warren-guard.js`) backstops obvious leaks and project deletes (best-effort, fails open).
- Destructive work and cron triggers require explicit human approval. Agent-authored commits are attributed to **Kay / K-Bot-T1**; human commits to the repo owner.

See `docs/warren-integration/` for the full design and ground-truth report.
