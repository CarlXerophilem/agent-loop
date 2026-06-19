# governance.md — Proxy usage-governance protocol

> **Status:** scaffold · Mirrors **plan §9**. The single load-bearing honesty constraint of the whole harness.

## The honest constraint (state it, honor it everywhere)

Remaining account usage is **NOT machine-readable**. There is no env var, hook field, CLI subcommand, or statusline field that reads it. The Admin usage API needs org credentials (unavailable on Pro/Max). The Workflow `budget` tracks only *self-imposed output tokens this turn*. `/usage` and `/cost` are human-eyes-only.

> **IRON RULE.** All "usage governance" here is a **wall-clock + operator-target proxy with a human `/usage` sensor**. **It does NOT self-throttle on the real account cap.** Never describe it as if it does.

---

## The 4 layers

| # | Layer | Signal | Authority |
|---|---|---|---|
| a | **Wall-clock vs `budget.json`** | elapsed since `state/session.start` vs `session_budget_minutes` | **authoritative** in-session signal |
| b | **Workflow `budget`** | self-imposed output-token ceiling this turn (`output_token_target`) | bounds one turn, **not** the account |
| c | **Human `/usage` relay** | operator reads `/usage` at session end → writes it into the *next* launch note | the **only real sensor** (refinement #1) |
| d | **hud + governance hook** | claude-hud statusline + a `Stop`/`PreToolUse` hook (modeled on ralph's `stop-hook.sh`, shipped as `hooks/budget-gate.sh`) | enforces warn/shed/stop |

Layer (a) drives decisions live; (c) corrects the proxy across sessions; (b) and (d) are mechanical guards.

---

## `config/budget.json` fields

```jsonc
{
  "session_budget_minutes": 300,          // window the operator INTENDS to spend
  "weekly_session_fraction": 0.20,        // "5h-of-weekly proportion" — operator bookkeeping
  "warn_at_elapsed_fraction": 0.70,       // start shedding T2/T3 work
  "hard_stop_at_elapsed_fraction": 0.90,  // stop spawning, write handoff, exit
  "output_token_target": 500000           // mirrors the Workflow budget "+500k" directive
}
```

`elapsed_fraction = (now − session.start) / session_budget_minutes`.

---

## What warn / hard_stop do

| Threshold | Trigger | Action |
|---|---|---|
| **warn** | `elapsed_fraction ≥ warn_at_elapsed_fraction` | hook warns; **shed T2/T3** — stop admitting new improvement/stretch work; finish in-flight T0/T1 |
| **hard_stop** | `elapsed_fraction ≥ hard_stop_at_elapsed_fraction` | **stop spawning** any worker; write `state/HANDOFF.md`; exit cleanly; optionally schedule a resume Routine |

The hook must be **additive and fast** (`exit 0`-clean) so it never clobbers the logger Stop hook (plan R7) — append to hook arrays, don't replace.

---

## The weekly fraction (cross-window)

`weekly_session_fraction` is **purely the operator's stated intent**, tracked in `state/weekly.ledger.json`. The harness refuses to **start a new Routine session** if the running sum would exceed it. Cross-window spanning uses **Routines** (`/schedule`) — session cron / `/loop` tasks cannot survive the window.

Mitigations (plan R1): conservative `warn_at` 0.6–0.7; human `/usage` at session end → next launch note; operator owns `weekly.ledger.json`.

<!-- expand here: exact budget-gate.sh stdin/JSON contract; how it reads session.start; resume-Routine scheduling snippet; ledger update format -->
