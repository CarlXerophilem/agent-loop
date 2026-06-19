---
scenario: Two laptops over a shared git remote, host-coordinator on laptop A
mode: engineering
operators: 2 (laptop A = host-coordinator + worker; laptop B = worker)
substrate: shared SolveIterativeFunctions GitHub remote (git IS the source of truth)
walks: request → single grant → no-double-grant → conflict decision tree → host-down failover
note: Multi-user is a CONVENTION layered on shared git, not a Claude Code feature (plan §11). No shared token budget, no cross-account spawning, no atomic locks. The single-grantor host makes races impossible WHILE IT IS UP; otherwise best-effort.
---

# Walkthrough — two laptops, host-coordinator dispatch

Two collaborators, one repo. **Laptop A** runs the long-lived host-coordinator (and also
spawns workers); **laptop B** runs a worker session only. They never share a process — only a
git remote. Every coordination act is a jsonl row that gets pushed and pulled.

The point: show that the **sole-grantor** host eliminates the claim race, how a second contender
is steered without a double-grant, how a writing conflict is resolved by the decision tree, and
what happens when the host goes down.

---

## 0. Substrate & roles

```
remote: github.com/CarlXerophilem/SolveIterativeFunctions   (git = source of truth)
laptop A:  host-coordinator (sole claim grantor, verifier, KB, merge arbiter) + worker w-a
laptop B:  worker w-b   (acts ONLY on a host grant in state/grants.jsonl)
branches:  auto/<operator>/<todo-id>   ·   workers use local isolation:'worktree'
```

Both started from the same `HANDOFF.md`. The shared backlog has two independent T1 items left:

```jsonl
{"id":"T-11","title":"add Schroeder half-iterate worked example for f(x)=2x/(1+x)","tier":"T1","deps":[]}
{"id":"T-12","title":"composita.html: show F^Δ(n,k) table for first 6 rows","tier":"T1","deps":[]}
```

---

## 1. Laptop B appends a request + pushes

Worker `w-b` wants work. It does **not** grab a TODO — it appends a *request* to
`state/requests.jsonl` and pushes. Requests are append-only, so the push union-merges cleanly:

```jsonl
# state/requests.jsonl   (laptop B appends, then: git add -A && git commit && git push)
{"todo":"T-11","operator":"laptop-b","agent":"w-b","ts":"2026-06-20T02:10:04Z","op":"request"}
```

At nearly the same wall-clock, laptop A's own worker `w-a` wants the *same* item and appends its
own request:

```jsonl
{"todo":"T-11","operator":"laptop-a","agent":"w-a","ts":"2026-06-20T02:10:06Z","op":"request"}
```

Two contenders, one item. In a leaderless design this is the classic earliest-`ts` race. Here it
isn't — there is exactly one grantor.

---

## 2. Host grants exactly ONE → `grants.jsonl` + pushes

The host (laptop A) pulls, sees two requests for T-11, and **grants exactly one**. It picks `w-b`
(earlier `ts`, and load-balances off its own laptop), writes one grant row, and pushes:

```jsonl
# state/grants.jsonl   (host appends, commits, pushes)
{"todo":"T-11","operator":"laptop-b","agent":"w-b","ts":"2026-06-20T02:10:31Z","op":"grant"}
```

> **The race is gone (plan §11).** Earliest-`ts` arbitration no longer decides anything — the
> host does. There is no window in which both contenders believe they own T-11, *as long as the
> host is up*.

Laptop B pulls, sees the grant for `agent=w-b todo=T-11`, and only **now** starts working —
in its worktree on branch `auto/laptop-b/T-11`.

---

## 3. The second contender is told to take the next item (no double-grant)

`w-a` (laptop A's worker) is still requesting T-11. The host does **not** grant it T-11 — that
would be a double-grant. Instead, in the same dispatch pass, it grants `w-a` the *next* free
cut-line item, T-12:

```jsonl
# state/grants.jsonl  (same push)
{"todo":"T-12","operator":"laptop-a","agent":"w-a","ts":"2026-06-20T02:10:32Z","op":"grant"}
```

So both workers proceed, on disjoint items, on disjoint branches. The dispatch invariant: **at
most one open `grant` per `todo` at any time.** A contender that loses a grant is always handed
forward to the next item, never left spinning and never double-granted.

---

## 4. A writing conflict, resolved by the decision tree

T-11 and T-12 both add a worked example to a *shared* explanation file, `theory.html`. When the
host integrates `auto/laptop-b/T-11` and `auto/laptop-a/T-12`, git flags a conflict in one
region. The host walks the **writing-conflict decision tree** (plan §11):

| # | Test | This case | Action |
|---|---|---|---|
| 1 | regions **disjoint**? | the two examples touch **different `<section>` blocks** | **auto union-merge** ✓ |
| 2 | overlap, one strictly higher tier/confidence? | n/a (disjoint) | — |
| 3 | overlap, comparable? | n/a | — |
| 4 | irreconcilable / semantic? | n/a | — |

Branch 1 fires: the additions are **disjoint** (B added a `2x/(1+x)` example section; A added the
F^Δ table to a different section), so the host **union-merges** — both blocks land, no human
needed. It records the resolution in `state/kb.digest.md`:

```md
### merge 2026-06-20T02:48 — theory.html
T-11 (w-b) + T-12 (w-a): disjoint <section> regions → union-merge (tree branch 1).
Both worked examples now present; lint clean; pushed to main by host.
```

> Had the two edited the **same** lines (branch 3/4): comparable tier → host synthesizes a
> **mixed merge**; truly irreconcilable/semantic → **park + flag in `HANDOFF.md`** for the next
> launch. The tree never silently drops a contributor's work.

---

## 5. Host-down failover → leaderless claims

Mid-session, laptop A closes its lid — the host is **down**. A new free item T-13 appears and
`w-b` needs work, but there is no grantor. The workers fall back to the **degraded mode**:
leaderless optimistic claims (plan §11, R6 SPOF mitigation).

`w-b` appends an earliest-`ts` *claim* (not a request — there's nobody to grant it), pushes
immediately, then pulls to check it wasn't beaten:

```jsonl
# state/claims.jsonl   (failover only — host is down)
{"todo":"T-13","operator":"laptop-b","agent":"w-b","ts":"2026-06-20T03:30:09Z","op":"claim"}
```

Now earliest-`ts` **does** arbitrate again, because the single grantor is gone. If a competing
claim with an earlier `ts` is pulled, `w-b` **yields**:

```jsonl
{"todo":"T-13","operator":"laptop-b","agent":"w-b","ts":"2026-06-20T03:30:14Z","op":"yield"}
```

When laptop A comes back, the host resumes sole-grantor mode; in-flight leaderless claims are
honored, and new dispatch goes back through `requests.jsonl → grants.jsonl`. Host state is just
git files, so recovery is a pull.

---

## The jsonl rows at a glance

| File | Who writes | Row `op` | Race-safe because |
|---|---|---|---|
| `requests.jsonl` | any worker | `request` | append-only; host decides, not `ts` |
| `grants.jsonl` | **host only** | `grant` | one grantor ⇒ ≤1 open grant per todo |
| `claims.jsonl` | workers (failover) | `claim`/`yield` | host down ⇒ earliest-`ts` + push/pull/yield |

> **Flagged honestly (plan §11):** no shared token budget across the two accounts, no
> cross-account agent spawning, no atomic locks. While the host is up, races are impossible;
> when it's down, this is best-effort optimistic concurrency. Scope: two trusting laptops, git as
> the single source of truth — never force-push a shared branch.
