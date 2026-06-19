# grants-protocol.md — Host dispatch + leaderless failover

> **Status:** scaffold · Mirrors **plan §11**. Substrate = a **shared git remote** (the pilot uses the SolveIterativeFunctions remote). Multi-user is a **convention layered on shared git**, not a Claude Code feature.

## Host-coordinator dispatch (single grantor → no race)

The host-coordinator is the **single source of truth and sole claim grantor**. The earliest-`ts` race is eliminated because exactly one process grants.

```
worker:  append a REQUEST to state/requests.jsonl   →  git push
host:    read requests, grant EXACTLY ONE to state/grants.jsonl  →  git push
worker:  act ONLY on a host grant (pull, see your grant, proceed)
```

A worker never self-authorizes; it waits for its row to appear in `grants.jsonl`.

---

## Row schema (`requests.jsonl` / `grants.jsonl` / `claims.jsonl`)

```jsonc
{ "todo": "<id>", "operator": "<name>", "agent": "<id>", "ts": "<utc-iso>", "op": "claim|grant|yield|release" }
```

| Field | Meaning |
|---|---|
| `todo` | backlog id / field-node id being claimed |
| `operator` | which laptop/account |
| `agent` | the `AGT(…)` worker id |
| `ts` | UTC ISO timestamp (the tiebreak key in failover) |
| `op` | `claim` (want it) · `grant` (host authorizes) · `yield` (back off) · `release` (done) |

Branch/worktree per operator: `auto/<operator>/<todo-id>`; agents use local `isolation:'worktree'`; the host (or a human) integrates; **never force-push shared branches.**

---

## Writing-conflict decision tree (host arbitrates)

| # | Situation | Resolution |
|---|---|---|
| 1 | disjoint regions | auto **union-merge** |
| 2 | overlap, one strictly higher tier/confidence | **it wins** |
| 3 | overlap, comparable | host synthesizes a **mixed merge** |
| 4 | irreconcilable / semantic | **park + flag in `HANDOFF.md`** for the next launch |

---

## Leaderless failover (SPOF mitigation, plan R6)

> **IRON RULE — degraded, best-effort.** Single-grantor makes races impossible *only while the host is up*. With the host down it is best-effort: no atomic locks across accounts.

If the host is down, workers fall back to **leaderless optimistic claims**:

```
1. CLAIM: append earliest-ts claim to state/claims.jsonl  →  immediate git push
2. PULL:  git pull  →  re-read claims.jsonl
3. RESOLVE: the earliest ts for that todo wins
4. YIELD: if someone beat you (earlier ts), append op:"yield" and back off
```

The host's state is **just git files**, so a cloud-Routine host or laptop-A host are interchangeable — recovery is automatic when a grantor returns. An optional MCP bus (Slack/Linear) gives lower-latency notices, but **git stays the source of truth**.

<!-- expand here: host poll cadence; how a stale grant (worker died holding it) is reclaimed; example requests→grants exchange; MCP-bus notice format -->
