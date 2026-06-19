# deep-reasoning-loop.md — Solver → rest → verifier → revise

> **Status:** scaffold · Mirrors **plan §6.2** (refinement #3). For "ultra-long-thinking" tasks — a proof step, a rigor check. **Do not** run one monolithic agent; loop.

## The loop

| Step | Actor | Mechanism |
|---|---|---|
| 1 | **Solver** | effort `xhigh`/`max` emits a candidate |
| 2 | **Orchestrator rests** | `ScheduleWakeup` short interval **60–270s (cache-warm)** instead of busy-waiting |
| 3 | **Independent verifier** | runs in order of availability (see below), with **no-anchoring isolation** |
| 4 | **Verifier writes** | a **mirrored rigor critique** to `state/blackboard.md` |
| 5 | **Solver revises** | next wake reads the critique and revises |

**Loop until sign-off or a round cap.** Always set the round cap (anti-non-termination, plan R2).

---

## Verifier order (graceful degradation)

1. **Cross-model bridge** — `hooks/cross-verify.sh`, extending the operator's `shared/cross_model_verification.md`. Providers: `deepseek-*` / `gpt-*` / `gemini-*`. See `cross-model-bridge.md`.
2. **Same-family DA panel (fallback)** — reuse deep-research's `devils_advocate_agent` / `source_verification_agent` personas. This is the **no-key** path.

> **IRON RULE — never block on a bridge failure.** If `cross-verify.sh` exits 2 (`CROSS_MODEL_AVAILABLE=none`), fall straight through to the DA panel. The loop never stalls waiting on an external API.

---

## No-anchoring isolation

> The verifier **never sees the solver's reasoning** — only the claim/artifact under review. This follows the operator's `ground_truth_isolation_pattern.md`: anchoring on the solver's chain-of-thought defeats the point of an independent check. The verifier is told it did **not** write the work.

Novel issues the verifier raises (not already covered) are tagged **`[CROSS-MODEL-FINDING]`** so the solver can prioritize them on its next wake.

---

## "Mirror" = two complementary jobs

| Sense | What it buys |
|---|---|
| **Independent re-derivation** | consensus — a second path reaching the same result |
| **Third-party critique** | rigor — an adversary attacking the weakest step |

A round may use either or both.

---

## In generative mode

Each promising **frontier step** is itself one of these verify-loops (plan §7.5): it either **anchors a new `baseline_anchored` landmark** or **sharpens the gap geometry**. Sign-off there means "this atom is cross-model-verified," which grows the verified component outward — never a "solved" verdict on the whole problem.

<!-- expand here: exact rest-interval tuning vs cache TTL; round-cap defaults; the verifier prompt skeleton; how [CROSS-MODEL-FINDING] flags are reconciled at the round boundary -->
