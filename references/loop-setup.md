# loop-setup.md — The two co-equal loop engines

> **Status:** scaffold · Mirrors **plan §10 + R4**. Neither engine is defaulted — **operator choice**. A skill cannot loop itself; the loop lives here.

## The two engines

| | **A. Native `/loop` dynamic** | **B. ralph-loop `Stop` hook** |
|---|---|---|
| Engine | model schedules its own next wake-up (`ScheduleWakeup`, 60–3600 s), re-injecting the loop prompt | a `Stop` hook reads `.claude/ralph-loop.local.md`, parses the last assistant block, re-injects the prompt or lets the session exit |
| Completion | the model schedules **no further wake-up** | the model emits **`<promise>EXACT TEXT</promise>`** |
| State | session task list | YAML state file: `active / iteration / session_id / max_iterations / completion_promise / started_at` |
| Pros | native, self-pacing, cache-aware | self-contained, fully inspectable, battle-tested |
| Cons | session must stay open; ~7-day task expiry | **Windows git-bash pinning needed** |

**Recommendation:** pilot **both**; pick per operator. Phases 1–6 are identical underneath either engine.

---

## Completion criteria (either engine)

Stop when **any** holds:

- all **T0 + T1** are `done` (verified by tests/lint), **or**
- `elapsed_fraction ≥ hard_stop` (see `governance.md`), **or**
- `max_iterations` reached — **always set one** (plan R2), **or**
- only `blocked` / `deep-frontier` work remains.

> **IRON RULE — honest completion.** Emit the completion token / schedule-no-wakeup **only when genuinely true.** Completion is gated on tests/lint, not self-report. Never lie to finish (plan R2).

---

## Windows git-bash pinning note (plan R4)

On Windows, pin the interpreter so hooks and sub-tools resolve a real bash:

```
"C:/Program Files/Git/bin/bash.exe"
```

Also: keep `state/` names **ASCII**, and run path-sensitive tools from an ASCII directory (the project's own path is non-ASCII — `公众号文章` — which breaks some sub-tools if used as cwd).

---

## Engine B — the ralph wiring (sketch)

- `.claude/ralph-loop.local.md` — the loop prompt + the YAML state block.
- The `Stop` hook (modeled on ralph's `stop-hook.sh`) reads that file, checks `active` / `iteration < max_iterations`, looks for the `<promise>` token in the last assistant block; if absent and under cap, re-injects the prompt, else lets the session exit.
- Must be **additive** to existing Stop hooks (don't clobber the logger Stop hook — plan R7).

## Engine A — the native wiring (sketch)

- `/loop` in dynamic mode lets the model call `ScheduleWakeup(delaySeconds)` itself (60–3600 s), re-injecting the loop prompt each wake.
- The deep-reasoning rest intervals (60–270 s, `deep-reasoning-loop.md`) ride on the same `ScheduleWakeup` primitive.

<!-- expand here: full ralph-loop.local.md YAML template; stop-hook.sh decision flow; ScheduleWakeup cadence vs cache TTL; how max_iterations is surfaced to the model each wake -->
