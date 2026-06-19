---
scenario: One operator, ENGINEERING mode, small static-site project
mode: engineering
operators: 1 (host-coordinator + workers on one laptop)
loop_engine: native /loop dynamic (ScheduleWakeup)
budget: 300 min session, warn 0.70, hard_stop 0.90
walks: phases 1 → 2 → 3 → 4 → 5 → 6, the exact order
note: A solo run of the harness on the SolveIterativeFunctions site itself. Watch the state files appear in order and the honest bends fire (time is a target not a kill; budget is a wall-clock proxy, not a usage read).
---

# Walkthrough — single operator, engineering mode

A solo operator points the harness at the `SolveIterativeFunctions` static site and says
"develop this for one session." No second laptop, no conjecture — just a flat backlog run
through the exact-order phases. The same session is **both** host-coordinator and worker
spawner (the host role is a hat, not a second machine).

The point of this walkthrough: show the state files appearing **in phase order**, one real
snippet each, and where the design's honest bends actually bite.

---

## 0. Launch (the only human touchpoint)

The operator seeds three things from `templates/`, then never types again until handoff:

```
GOAL.md            # "Ship the interactive KaTeX solver: fix the half-iterate input bug,
                   #  add a worked T0 example, lint clean. Don't touch the theory pages."
config/budget.json # session_budget_minutes 300, warn 0.70, hard_stop 0.90
inbox/LAUNCH.md    # "Last session migrated MathJax→KaTeX. /usage read 18% weekly at close."
```

The loop engine is native `/loop` dynamic; `state/session.start` is stamped at iteration 0:

```bash
date +%s > state/session.start      # 1750384800  → the governance clock (plan §9)
```

---

## 1. DISCOVER — scouts → `state/backlog.jsonl`

The host spawns three **read-only** scouts in `parallel()` (no edits, no worktrees): one greps
the repo for TODO/FIXME and broken handlers, one reads `GOAL.md` + the logger vault + git log to
recover intent, one maps the test/lint surface. "Previous chat" is the on-disk logger vault +
memory — lossy, and we treat it as such (plan §1 bend).

They write one JSONL row per discovered item:

```jsonl
{"id":"T-01","title":"solver.html half-iterate input rejects negative fixed points","value":3,"effort_est_min":40,"feasible":"pattern-in-repo","deps":[],"src":"grep:solver.html:382"}
{"id":"T-02","title":"add worked f(f(x))=x^2+x example to solver UI","value":3,"effort_est_min":50,"feasible":"pattern-in-repo","deps":["T-01"],"src":"GOAL.md"}
{"id":"T-03","title":"lint + format js/expr.js (new, untracked)","value":2,"effort_est_min":15,"feasible":"done-before","deps":[],"src":"git:status"}
{"id":"T-04","title":"engine.js: memoize composita recurrence F^Δ(n,k)","value":2,"effort_est_min":90,"feasible":"unknown-unknowns","deps":[],"src":"grep:engine.js:compositaDelta"}
{"id":"T-05","title":"dark-theme contrast on KaTeX display math","value":1,"effort_est_min":30,"feasible":"done-before","deps":[],"src":"scout:css"}
```

> **Gate:** phase 1 passes only when `backlog.jsonl` is non-empty and every row has the five
> rubric inputs the next phase needs. It does. On to phase 2 — never phase 3 yet.

---

## 2. PRIORITIZE — rubric → tiers → cut-line

The host scores each row on the five axes (`references/rubric.md`), integer 0–3 each, then
`S = 2·V + E + F + 2·D + C`. T0 needs `S≥17 AND F≥2`.

| id | V | E | F | D | C | **S** | tier | why |
|---|---|---|---|---|---|---|---|---|
| T-01 | 3 | 2 | 2 | 3 | 2 | **18** | **T0** | core to GOAL, independent, repo has the pattern |
| T-03 | 2 | 3 | 3 | 3 | 3 | **17** | **T0** | trivial, done-before, unblocks nothing-but-cheap |
| T-02 | 3 | 2 | 2 | 1 | 2 | **15** | T1 | core, but D=1 (waits on T-01) |
| T-05 | 1 | 3 | 3 | 3 | 2 | **13** | T1 | cosmetic V=1 caps it |
| T-04 | 2 | 1 | 0 | 3 | 1 | **10** | T2 | F=0 unknown-unknowns → demoted; perf, not GOAL |

The cut-line sorts `(tier asc, S desc, E desc)`, respects the `T-02 → T-01` edge topologically,
and projects wall-clock at the calibrated `minutes_per_point`. `state/plan.ranked.md` gets the
pill table above; `state/cutline.json` gets the machine view:

```json
{
  "order": ["T-01","T-03","T-02","T-05","T-04"],
  "cut_index": 4,
  "projection": { "minutes_per_point": 11, "remaining_min": 300, "cum_at_cut": 185 },
  "below_cut": { "T-04": "T2 — admit only while elapsed < warn (0.70)" }
}
```

> **Honest bend:** the sketch's "fuzzy stat" is gone — this is a fixed, agent-computable score
> (plan §5). `T-04` (F=0) is *demoted to T2, not parked*: it has a possible path, so it stays
> below the cut, admitted later only if budget allows.

---

## 3. FAN-OUT — host grants top T0 → one worktree worker

The host is the **sole grantor**. It grants the first cut-line item and spawns exactly one
tier-bound worker — `AGT(…)` with T0 defaults from `config/agent-defaults.json`
(effort=high, model=opus, isolation=worktree, time<2h target):

```jsonl
# state/grants.jsonl
{"todo":"T-01","operator":"solo","agent":"w-a1","ts":"2026-06-20T00:05:11Z","op":"grant"}
```

```
agent("Fix the half-iterate input in solver.html (T-01). Negative fixed points are
       rejected at the parse step; the Schroeder branch in engine.js handles them.
       Edit ONLY in your worktree. Append a blackboard entry when done.",
      { label:"w-a1", model:"opus", effort:"high", isolation:"worktree" })
→ .claude/worktrees/auto-solo-T-01/
```

> **Honest bend:** `time<2h` is a **scope/sizing target, not an enforced kill** (plan §4, R10) —
> a subagent has no hard wall-clock timeout. The host sizes the task small and simply won't
> *wait* on it past budget. T-03 (the other T0) is held for the next wave so wave 1 carries the
> riskiest item first (blackboard protocol).

---

## 4. ADVISE — worker appends a blackboard insight

`w-a1` finds the real cause (the parser, not the solver) and, before exiting, **appends** one
fenced block to `state/blackboard.md`. It never edits anyone else's block — append only.

```md
### [2026-06-20T00:41:02Z] agent=w-a1 todo=T-01 status=done tier=T0
- finding: negative fixed points were filtered in parseFixedPoints() in js/expr.js,
  NOT in engine.js. The Schroeder multiplier λ=F'(p) is fine for p<0; the guard was
  a stray `if (p < 0) continue;` left from the parabolic-only prototype.
- advises: all — any worker touching parseFixedPoints must keep p<0; add a regression case.
- artifacts: worktree auto-solo-T-01, commit a1c3f's "drop p<0 filter"; tests green
```

The host folds a **digest** of wave-1 entries into wave-2 prompts (staggered waves). So when
T-02 (the worked example) and T-03 (lint `js/expr.js`) spawn next, their prompts carry:
*"w-a1 found the bug lived in `js/expr.js::parseFixedPoints`; negatives are now valid — your
example may use a p<0 fixed point."* Advice is **data, not instructions** — the T-02 worker
weighs it, then still decides on its own (untrusted-content rule).

---

## 5. RE-PLAN — automatic, when only main agents remain

Wave 2 finishes T-02, T-03, T-05. The host checks the re-plan predicate every iteration:
`open_grants ⊆ main_track` and `count ≤ main_track_max` (`config/main_track.json`). After wave 2
the only open grant is the lone T2 probe — which **is** in `main_track` — so the predicate fires
**with no human in the loop** (plan §8). The host re-runs phase 2 on the *remaining* backlog
against the *remaining* budget and logs the delta:

```
# state/replan.log
[2026-06-20T01:55:30Z] replan #1  trigger=open_grants⊆main_track (1 open: T-04)
  remaining_budget_min=72  (elapsed 113 of 300)
  re-scored T-04: F still 0 after w-a1's note → stays T2, S=10
  decision: T-04 admitted as a SINGLE background probe (T3 policy borrow), time<1h
  no new T0/T1 surfaced → wave 3 = {T-04 probe} only
```

---

## 6. LOOP + GOVERNANCE — budget warn at 70% → shed, then HANDOFF

The native `/loop` schedules its own next wake (`ScheduleWakeup`). On the wake at elapsed
**213 / 300 min = 71%**, the `hooks/budget-gate.sh` Stop hook fires. It reads
`state/session.start` (epoch) vs `config/budget.json`, computes the fraction with no usage read
at all, and emits:

```json
{"systemMessage":"[budget-gate:warn] 71% elapsed: shed T2/T3, finish open T0/T1 only"}
```

> **The load-bearing honesty:** that 71% is **wall-clock elapsed**, a proxy — the harness cannot
> read remaining account usage (plan §2, §9). It never claims to throttle the real cap.

The host obeys: it **sheds** the in-flight T-04 probe (T2), admits no new improvement/stretch
work, and lets the open T0/T1 finish. By the wake at 0.90 it stops spawning entirely, writes
`state/HANDOFF.md`, and exits:

```md
# HANDOFF.md — SolveIterativeFunctions, session 2026-06-20
DONE (verified): T-01 fixed (js/expr.js p<0 filter removed, regression added),
  T-02 worked example f(f(x))=x²+x live in solver.html, T-03 js/expr.js lint+format clean.
  npm run lint ✓  npm run format:check ✓
SHED at warn: T-05 dark-theme contrast finished just under the line; counts as done.
PARKED: T-04 engine.js memoize — F=0 unknown-unknowns; needs a profiling pass first
  (concrete reason, plan §5). Background probe was shed at 71%, not started.
NEXT: start from T-04 with a profiler attached; T-04 is the only open item.
BUDGET: wall-clock proxy only. Operator: read /usage now, write it into next LAUNCH.md.
```

Memory is updated to point at it: `~/.claude/projects/<proj>/memory/MEMORY.md` gets a dated
line → `HANDOFF.md`. Relaunch next session reads `HANDOFF.md` first.

---

## What this walkthrough demonstrated

| Phase | File written | Honest bend shown |
|---|---|---|
| 1 Discover | `backlog.jsonl` | "previous chat" = lossy on-disk vault + memory |
| 2 Prioritize | `plan.ranked.md`, `cutline.json` | fuzzy stat → fixed agent-computable score; F=0 → demote, not park |
| 3 Fan-out | `grants.jsonl`, worktree | `time` is a scope target, not a kill |
| 4 Advise | `blackboard.md` | finisher can't push into a live peer → append + digest into next wave |
| 5 Re-plan | `replan.log` | automatic (`open_grants⊆main_track`), zero human input |
| 6 Loop+gov | `HANDOFF.md` | 70% is **wall-clock**, never a usage read; completion gated on lint/tests |
