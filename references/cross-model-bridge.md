# cross-model-bridge.md — `hooks/cross-verify.sh`

> **Status:** scaffold · Mirrors **plan §6.2 / R9** and the live script at `hooks/cross-verify.sh`. **Extends** the operator's `academic-research-skills/shared/cross_model_verification.md` with a DeepSeek case.

Sends a verification **prompt** to an **independent** model (no-anchoring: the verifier is told it did NOT write the work) and prints its critique on stdout. **Never blocks the loop.**

```
cross-verify.sh "verification prompt"      # or pipe the prompt on stdin
```

---

## Provider selection

The provider is chosen by **`$AUTO_DEV_CROSS_MODEL`** plus the **matching API key**. If neither resolves, it prints `CROSS_MODEL_AVAILABLE=none …` and **exits 2** → the caller uses the **DA panel** (`deep-reasoning-loop.md`).

| `AUTO_DEV_CROSS_MODEL` matches | Required key | Endpoint |
|---|---|---|
| `deepseek*` | `DEEPSEEK_API_KEY` | `api.deepseek.com/chat/completions` |
| `gpt-5*` / `gpt*` | `OPENAI_API_KEY` | `api.openai.com/v1/chat/completions` |
| `gemini*` | `GOOGLE_AI_API_KEY` | `…/v1beta/models/${MODEL}:generateContent?key=…` |
| (anything else / unset) | — | prints `CROSS_MODEL_AVAILABLE=none`, **exit 2** |

A set `AUTO_DEV_CROSS_MODEL` whose key is missing also yields `none`+exit-2 (e.g. `CROSS_MODEL_AVAILABLE=none (no DEEPSEEK_API_KEY)`).

---

## Contract

| Aspect | Detail |
|---|---|
| Input | `$1` prompt, else stdin; empty ⇒ `none`+exit 2 |
| System prompt | fixed: "independent verification assistant … you did NOT write the work … find the most serious weaknesses; if rigorous, say so" |
| Params | `temperature 0.1`, `max_tokens 2000` (low-variance, bounded) |
| JSON-escape | `python3 -c json.dumps`, falling back to `node` |
| Response extract | provider-specific path (`choices[0].message.content`, or Gemini `candidates[0].content.parts[0].text`) |
| Output | the model's critique text on stdout |
| Failure | `CROSS_MODEL_AVAILABLE=none …` + **exit 2** (the agreed "use the DA panel" signal) |

> **IRON RULE — exit 2 means fall back, not fail.** Treat exit 2 as "cross-model unavailable, use the same-family DA panel," never as an error that stops the deep-reasoning loop (plan R9, graceful degradation).

---

## Cost / latency notes

- Adds ~2–5 s per call; low-temp + 2000-token cap keeps cost small (rough order: cents per call, matching the operator's `cross_model_verification.md` cost table).
- Called once per verify **round**, not per step — bounded by the round cap.
- Keep the verification prompt **simple and structured**; response formats differ across providers and the extractor is deliberately thin.

## Relationship to the operator bridge

This script is the auto-dev-specific **extension** of `shared/cross_model_verification.md`: same env-var convention and curl patterns, same `[CROSS-MODEL-FINDING]` flagging discipline, but renamed to `AUTO_DEV_CROSS_MODEL` and **adds the DeepSeek provider case**. Adding DeepSeek + an embeddings endpoint to the bridge is otherwise a deferred, on-demand item (plan §13).

<!-- expand here: response-shape quirks per provider; retry/backoff policy on 429; wiring cross-verify.sh output back into a [CROSS-MODEL-FINDING] blackboard entry -->
