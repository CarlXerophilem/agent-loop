# knowledge-field-schema.md — `state/field.json` data model

> **Status:** scaffold · Mirrors **plan §7.2** exactly. The generative-mode knowledge base. In host-coordinator terms, the KB *is* this file (plan §11).

## Node schema

```jsonc
node = {
  id,
  kind: "landmark|lemma|approach|analogy|obstruction|reformulation",
  statement,
  location: {                       // THE GEOMETRY — replaces any solved/unsolved status
    cluster,
    nearest_landmarks: [{ id, hops, relation, semantic_dist }],
    frontier_distance,              // hops / semantic distance to the nearest VERIFIED baseline
    gap_geometry,                   // "one missing lemma" | "missing technique"
                                    //   | "cross-domain bridge" | "dense well-understood neighborhood"
    coords                          // embedding position (bridge) or association signature (fallback)
  },
  verification: { checked_cases, cross_model_verdict, baseline_anchored: bool },
  leverage                          // downstream-unlock count
}
```

| Field | Role |
|---|---|
| `kind` | which of the six node types (see `generative-mode.md`) |
| `location.cluster` | which dense neighborhood it sits in |
| `location.nearest_landmarks` | the verified anchors closest to it, with hop count + relation + semantic distance |
| `location.frontier_distance` | distance to the nearest **verified** baseline — the core "how far out" measure |
| `location.gap_geometry` | the **shape** of what's missing, not whether it's possible |
| `location.coords` | embedding position (bridge) or association signature (fallback) — see `embeddings-bridge.md` |
| `verification.baseline_anchored` | true once cross-model-verified; mints a `landmark` |
| `leverage` | how many downstream nodes it would unlock |

---

## Edge schema

```jsonc
edge = { from, to, rel: "implies|specializes|analogous|bridges|depends", weight }
```

| `rel` | Meaning |
|---|---|
| `implies` | from ⊢ to |
| `specializes` | to is a special case of from |
| `analogous` | cross-domain correspondence |
| `bridges` | connects two clusters |
| `depends` | to needs from first |

`weight` carries edge strength (e.g. cosine similarity for `analogous`/`bridges`).

---

## The one non-negotiable

> **IRON RULE — NO status field.** There is **no** `status` of `unsolved` / `impossible` / `failed` anywhere in a node. The **`location` geometry replaces it.** The far end of the ladder is **`deep-frontier`** — a *positional descriptor*, computed from `frontier_distance` + `gap_geometry` + the landmark neighborhood — **not a defeat verdict.** (plan §7 IRON RULE; satisfies R2 + R12.)

The verified component grows as nodes flip `verification.baseline_anchored` to true; `frontier_distance` is always measured against that growing verified set. Geometry is **advisory and re-derivable** — never asserted as a solved/unsolved claim (plan R12).

<!-- expand here: a worked 3-node + 2-edge field.json instance; how frontier_distance is recomputed when a node becomes baseline_anchored; gap_geometry classification heuristics -->
