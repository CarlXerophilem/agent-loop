# embeddings-bridge.md — Computing "semi-connected" edges

> **Status:** scaffold · Mirrors **plan §7.3 + R12**. How the knowledge field's associative edges and node coords are derived. Extends the cross-model bridge (`cross-model-bridge.md`).

The field is **semi-connected**: edges exist only where associative proximity **exceeds a threshold**, so the graph is sparse + clustered + bridged, not a tree. Two ways to compute proximity, with a clean fallback.

---

## Primary: embeddings via an API endpoint

Extend the `cross-model bridge` with an **embeddings endpoint** (the same curl/env-var pattern as `cross-verify.sh`):

```
node.statement  ──embed──▶  vector  ──▶  node.location.coords
cosine(vec_i, vec_j) ≥ threshold  ──▶  weighted edge (rel: analogous|bridges, weight = cosine)
```

| Output | Where it lands |
|---|---|
| node embedding vector | `node.location.coords` (`knowledge-field-schema.md`) |
| cosine-over-threshold pair | a weighted `edge` |

Node coords **are** latent-space positions — "approaching the basis of the LLM framework" (plan §7.1).

---

## Fallback: LLM-judged association (no key)

When no embeddings key is available, an **LLM judges association** between node pairs and emits the same edges (weight = its judged strength) and an **association signature** in place of `coords`. Graceful degradation — the field still forms (plan §7.3, R12).

| Mode | Coords | Edges | Needs |
|---|---|---|---|
| Embeddings | true latent vector | cosine ≥ threshold | embeddings API key |
| LLM-judged (fallback) | association signature | judged strength ≥ threshold | nothing extra |

> **IRON RULE — geometry is advisory.** Embeddings need an external API and the geometry **could drift**; it is gated on a key, falls back to LLM-judged, stays **advisory + re-derivable**, and is **NEVER** asserted as a solved/unsolved claim (plan §7 IRON RULE, R12).

---

## Embedding-dedup (pruning)

The same embeddings power **anti-explosion** (`generative-mode.md`, plan R11): a candidate node whose embedding is within the dedup radius of an existing node is a **near-duplicate** and is **rejected at the verifier/DA gate**. This bounds field growth alongside per-cluster caps and budget governance.

```
if min_j cosine(new, node_j) ≥ dedup_threshold:  reject as near-duplicate
```

In the no-key fallback the same check is the LLM judging "is this materially new?".

---

## Status (deferred)

Adding an embeddings endpoint to the bridge is **deferred / on-demand** (plan §13) — gated on keys/usage. Until then the LLM-judged fallback is the working path. Thresholds (edge, dedup) + per-cluster caps are operator-tuned after a pilot (plan §13).

<!-- expand here: concrete embeddings endpoint + curl snippet; edge vs dedup threshold defaults; how coords feed frontier_distance; signature format for the fallback -->
