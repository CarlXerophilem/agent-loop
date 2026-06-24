---
scenario: One hard task via the deep-reasoning verify-loop (solver → rest → verifier → revise)
mode: engineering (single hard sub-task; the loop is mode-agnostic)
agents_used: [solver (xhigh/opus), orchestrator (rests), verifier (cross-model OR DA panel)]
mechanism: ScheduleWakeup rest instead of busy-wait; cross_model bridge with no-anchoring isolation; DA-panel fallback
walks: candidate → rest ~120s → verify (BOTH cross-model path AND no-key fallback) → revise → sign-off
note: "Mirror" means BOTH an independent re-derivation (consensus) AND a third-party critique (rigor). Graceful degradation: a bridge failure NEVER blocks — fall back to the devil's-advocate panel (plan §6.2).
---

# Walkthrough — the deep-reasoning verify-loop

One hard task, not a backlog: **prove the local analytic half-iterate of
`f(x) = x + x² + x³` near its parabolic-adjacent fixed point is uniquely determined to order 4 by
the Schroeder/composita coefficients** — and don't hand-wave the rigor. A single monolithic agent
would over-trust itself. So the harness loops: a solver emits a candidate, the orchestrator
**rests** (it does not busy-wait), an **independent** verifier critiques, the solver revises —
until sign-off or a round cap (plan §6.2).

---

## 0. Why a loop, not one agent

The IRON rule behind this loop: **never let the author grade its own proof.** The verifier must
be independent — ideally a *different model* — and must **never see the solver's reasoning**
(no-anchoring isolation), only the claim to be checked. We also set a hard `round_cap` so the
loop provably terminates (R2: always set a cap).

```jsonc
// the loop's own state
{ "task":"half-iterate-uniqueness-deg4", "round":0, "round_cap":4,
  "rest_seconds":120, "verifier":"auto", "signed_off":false }
```

---

## 1. Round 1 — Solver emits a candidate

`AGT(effort=xhigh, model=opus)` produces a candidate derivation and writes it to a scratch file
(`state/dr/cand.r1.md`), then appends a *pointer* to the blackboard (the proof body is data, kept
out of the verifier's prompt):

```md
### [2026-06-20T04:01:10Z] agent=solver todo=DR-1 status=insight tier=T0
- finding: candidate r1 — half-iterate g with g(g)=f; matched g's series g(x)=Σ c_k x^k
  order-by-order. Claim: c_1..c_4 are forced; c_1=1, c_2=1/2, c_3=1/8, c_4=−1/16.
- advises: verifier — check ONLY the claim "c_1..c_4 uniquely determined"; ignore my steps.
- artifacts: state/dr/cand.r1.md
```

## 2. Orchestrator RESTS (`ScheduleWakeup ~120s`)

The orchestrator does **not** spin. It schedules a short, cache-warm wake and yields the turn:

```
ScheduleWakeup(delaySeconds=120)   # 60–270s band, cache-warm (plan §6.2 step 2)
# … session is idle; no tokens burned busy-waiting …
```

Resting (not polling) is the whole trick: the verifier runs in the gap, and the solver's next
wake reads the result.

---

## 3a. Verifier — the cross-model path (key present)

A key **is** set (`AUTO_DEV_CROSS_MODEL=deepseek-reasoner`, `DEEPSEEK_API_KEY` exported). The
host calls the bridge with a **no-anchoring** prompt — the verifier is told it did *not* write the
work and is given only the *claim*, never `cand.r1.md`:

```bash
bash hooks/cross-verify.sh "INDEPENDENT CHECK. You did not write this. Claim: for
  f(x)=x+x^2+x^3, the order-1..4 coefficients of any formal half-iterate g (g∘g=f)
  are uniquely c_1=1,c_2=1/2,c_3=1/8,c_4=-1/16. Re-derive from scratch; find any
  error or unstated assumption."
# → returns DeepSeek's independent derivation + critique on stdout (exit 0)
```

It returns a **mirrored** result: an independent re-derivation (consensus check) *plus* a rigor
critique. The host writes it to the blackboard with the `[CROSS-MODEL-FINDING]` flag:

```md
### [2026-06-20T04:03:55Z] agent=verifier todo=DR-1 status=insight tier=verifier
- finding: [CROSS-MODEL-FINDING] (deepseek-reasoner, no-anchoring) — re-derived
  c_1=1, c_2=1/2 ✓. DISAGREES at c_3: gets c_3 = 1/16, not 1/8. The solver dropped the
  cross term 2·c_1·c_3 vs the x^3 coefficient of f; uniqueness HOLDS but the value is wrong.
- advises: solver — recheck the x^3 matching equation; c_4 likely shifts too.
- artifacts: cross_model verdict=DISAGREE@c3
```

## 3b. Verifier — the no-key fallback (devil's-advocate panel)

Run the same loop on a laptop with **no** API key. `cross-verify.sh` detects the missing key and
degrades — it never blocks the loop:

```
$ bash hooks/cross-verify.sh "INDEPENDENT CHECK ..."
CROSS_MODEL_AVAILABLE=none (no DEEPSEEK_API_KEY)         # exit 2
```

The host catches exit 2 and falls back to the **same-family devil's-advocate panel** (reusing
deep-research's `devils_advocate_agent` / `source_verification_agent` personas, plan §6.2 step
3b). Two opus personas, each told it did *not* write the proof, each re-deriving independently:

```md
### [2026-06-20T04:04:12Z] agent=verifier-DA todo=DR-1 status=insight tier=verifier
- finding: DA-panel (no key → same-family adversarial). DA#1 re-derived c_3=1/16 and
  flags the same dropped cross term; DA#2 confirms by an independent generating-function
  route. Consensus: uniqueness holds, solver's c_3 (and downstream c_4) are wrong.
- advises: solver — same fix as the cross-model branch would have given.
- artifacts: panel verdict=DISAGREE@c3 (degraded mode, no cross-model)
```

> **Graceful degradation (R9):** identical actionable verdict, lower independence. The loop is
> never blocked by a missing key or a bridge outage — it just drops from cross-model to panel.

---

## 4. Round 2 — Solver wakes, reads the critique, revises

The solver's `ScheduleWakeup` fires. At its checkpoint it re-greps the blackboard for advice
addressed to it:

```bash
grep -nE '^- advises: (all|solver)\b' state/blackboard.md
```

It reads the `DISAGREE@c3` critique, redoes the x³ matching equation (the cross term was indeed
dropped), and emits a corrected candidate:

```md
### [2026-06-20T04:06:40Z] agent=solver todo=DR-1 status=insight tier=T0
- finding: candidate r2 — corrected. c_3=1/16 (cross term 2·c_1·c_3 restored), which
  propagates to c_4=-1/32. Uniqueness argument unchanged and now consistent.
- advises: verifier — re-check c_3=1/16, c_4=-1/32.
- artifacts: state/dr/cand.r2.md   (round 2 of 4)
```

Orchestrator rests 120s again; the verifier (cross-model or DA panel) re-checks **only the
claim**.

---

## 5. Sign-off (or round cap)

The verifier re-derives and now **agrees** on every coefficient and on the uniqueness argument:

```md
### [2026-06-20T04:09:02Z] agent=verifier todo=DR-1 status=done tier=verifier
- finding: [CROSS-MODEL-FINDING] consensus — c_1..c_4 = 1, 1/2, 1/16, -1/32 confirmed by
  an independent re-derivation; uniqueness proof has no unstated assumption. SIGN-OFF.
- advises: all — DR-1 closed; treat these coefficients as a baseline-anchored result.
- artifacts: cross_model verdict=AGREE
```

The loop sets `signed_off=true` at round 2 of `round_cap=4` and exits. Had it hit the cap without
sign-off, it would **not** claim success (R2) — it would record the open disagreement and the
narrowest remaining gap into `HANDOFF.md`, honestly.

---

## The loop at a glance

| Step | Actor | Mechanism | Anti-self-trust guard |
|---|---|---|---|
| 1 | solver (xhigh/opus) | emits candidate → scratch + blackboard pointer | proof body kept out of verifier prompt |
| 2 | orchestrator | `ScheduleWakeup ~120s` (rest, not busy-wait) | cache-warm, zero spin tokens |
| 3a | verifier | `cross-verify.sh` → `[CROSS-MODEL-FINDING]` | different model, no-anchoring isolation |
| 3b | verifier | DA panel (no-key fallback) | same-family adversarial; never blocks (R9) |
| 4 | solver | re-greps `advises:`, revises | reacts to critique, doesn't re-grade itself |
| 5 | verifier | re-check → SIGN-OFF or round cap | cap guarantees termination (R2) |

> **"Mirror" = both:** an **independent re-derivation** (did two minds get the same coefficients?)
> *and* a **third-party rigor critique** (is the uniqueness argument actually airtight?). Consensus
> alone isn't sign-off; a clean critique alone isn't either — the loop wants both.
