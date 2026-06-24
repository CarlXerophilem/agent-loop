# rubric.md — Engineering-mode prioritization rubric

> **Status:** scaffold · Mirrors **plan §5**. Engineering mode only — generative mode replaces this entirely (see `generative-mode.md`, plan §7).

Turns the sketch's "interpolated boundary condition (baseline…impossible) by fuzzy stat" into a **fixed, agent-computable** scheme. No ML. Every axis is readable from repo + history. Weights/bands live in `config/rubric.json` so the operator retunes without touching logic.

---

## The 5 axes (integer 0–3 each)

| Axis | 0 | 3 | Source |
|---|---|---|---|
| **Value** (V) | cosmetic | core to GOAL | `GOAL.md`, issue text |
| **Effort-cheapness** (E) | >1 day | <30 min | file/diff/test-surface estimate |
| **Feasibility** (F) | unknown unknowns | done-before pattern in repo | repo grep, memory |
| **Dependency-freedom** (D) | blocked by ≥2 | independent | backlog edges (`state/backlog.jsonl`) |
| **Confidence** (C) | guessing | strong prior | logger vault, git log, memory |

Score each axis on its own merits; do not let one axis bleed into another (e.g. a cheap task that is cosmetic is still V=0).

---

## Score

```
S = 2·V + E + F + 2·D + C            # range 0–21
```

V and D are weighted **×2** for leverage: high-value, dependency-free work dominates. The weights are the multipliers in `config/rubric.json`.

---

## Tier ladder (the named "boundary condition")

| Tier | Name | Band | Policy |
|---|---|---|---|
| T0 | baseline | S≥17 **and** F≥2 | always in scope; do first |
| T1 | benchmark | 13–16 | in scope |
| T2 | improvement | 9–12 | in scope **if** elapsed < `warn` (see `governance.md`) |
| T3 | high (stretch) | 5–8 | single background `remote` **probe only** |
| T4 | blocked / deferred | S≤4 **or** F=0 with no path | park with a concrete reason; **never spawn** |

> **IRON RULE — far tier wording.** For engineering TODOs the far tier is **"blocked / deferred (with reason)"** — the rename from the sketch's "impossible_currently". For conjectures / hard *research* nodes even this is forbidden: generative mode positions by geometry and the far tier is `deep-frontier`, **never "unsolved"** (plan §7 IRON RULE).

The T0 `F≥2` gate is a guard: a high-S task with shaky feasibility is *not* baseline — demote it to T1 until feasibility is established.

---

## Cut-line algorithm

```
1. SORT backlog by (tier asc, S desc, E desc)            # cheapest tie-breaker last
2. TOPO-RESPECT dependency edges — a task never precedes a blocker
3. PROJECT wall-clock: cum_minutes += effort_points × minutes_per_point   (calibratable)
4. DRAW the cut where cum_minutes would exceed the remaining budget
     remaining = session_budget_minutes − elapsed   (from state/session.start, config/budget.json)
5. T3 stretch items below the cut survive ONLY as a single background remote probe
6. T4 items never enter the projection — park in state/parked.md with a reason
```

- `minutes_per_point` and `minutes_per_point` calibration are **deferred** until 1–2 real sessions of data (plan §13) — start with the `config/rubric.json` default and retune.
- Re-running the cut-line against the *remaining* budget is exactly what phase 5 (automatic re-plan) does — see plan §8 and `state/replan.log`.

**Outputs:** `state/plan.ranked.md` (pill table), `state/cutline.json` (ordered ids + cut index + projection inputs).

<!-- expand here: worked numeric example (a 6-item backlog → S, tier, cut); calibration procedure for minutes_per_point from logger timing data; how dependency cycles are detected/broken -->
