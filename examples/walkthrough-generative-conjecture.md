---
scenario: GENERATIVE mode on a terse hard conjecture (iterative / functional-equation domain)
mode: generative / research
core_data_model: semi-connected knowledge field (state/field.json) + geometry map (state/field.map.md)
seed: "Does there exist a real-analytic f with f(f(x)) = e^x − 1 on a neighborhood of 0, and is it unique?"
walks: Stage 1′ generate ~8–12 field nodes + associative edges → Stage 2′ position & frontier-map
note: CRUCIAL — the IRON RULE. No node is EVER labeled unsolved/impossible/failed. The conjecture node carries a `deep-frontier` LOCATION with a neighborhood map, which is itself informative (plan §7, satisfies R2).
---

# Walkthrough — generative mode on a conjecture

The operator seeds a **one-line hard statement** — no obvious decomposition, no TODO list:

> **Seed (`GOAL.md`):** *Does a real-analytic half-iterate of `f(x) = eˣ − 1` exist near 0
> (an `f` with `f∘f = eˣ−1`), and if so is it unique? `eˣ−1` has a **parabolic** fixed point at
> 0 (multiplier 1), so the Schroeder method the rest of the site uses does **not** apply.*

The launch classifier (`config/mode.json`) sees a terse conjecture with no decomposition and
picks **Generative / Research** mode. Phases 1–2 are replaced by **Stage 1′ generate the field**
and **Stage 2′ position & frontier-map** (plan §7). Phases 3–6 are shared with engineering mode.

> **THE IRON RULE (read first):** in generative mode a node is **NEVER** stamped
> `unsolved` / `impossible` / `failed`. Hard nodes are **positioned by geometry** — nearest
> verified landmarks, cluster, gap shape, bridges. The far tier is **`deep-frontier`**: a
> *location + neighborhood map*, not a defeat. This is also how we satisfy the anti-lying rule
> (R2): we never write "solved" and we never write "unsolved" — we write the truthful **position**,
> which is always informative.

---

## Stage 1′ — Generate the field → `state/field.json`

Divergent generator agents (`AGT`, effort=xhigh, **diverse personas**, background) unfold the
seed into nodes: decompositions (lemmas), candidate techniques (approaches), cross-domain
analogies, known obstructions, equivalent reformulations. They produced **11 nodes**:

| id | kind | statement (abbrev) |
|---|---|---|
| L-fatou | landmark | Existence of **formal** power-series half-iterate at a parabolic point (Écalle/Fatou coords) |
| L-abel | landmark | Abel equation `α(f(x)) = α(x)+1` ⇔ iteration; reduces composition to translation |
| R-fatou | reformulation | "half-iterate of `eˣ−1`" ⇔ "Fatou coordinate of `eˣ−1` admits a fractional shift by 1/2" |
| A-parab | approach | Parabolic iteration via formal Fatou coordinate at multiplier 1 |
| A-formal | approach | Build `g` as a **formal** series order-by-order; ask whether it **converges** |
| O-diverge | obstruction | Generic parabolic half-iterates are **formal but divergent** (Baker-type non-convergence) |
| AN-expm1 | analogy | `eˣ−1` is conjugate-adjacent to `x/(1−x)`-type maps with known half-iterate behavior |
| AN-ecalle | analogy | Écalle–Voronin moduli classify parabolic germs up to conjugacy |
| L-composita | landmark | The site's **composita** machinery computes the formal series coefficients exactly (verified) |
| RE-unique | reformulation | "uniqueness" ⇔ choice of a **real** Fatou coordinate among the formal family |
| FRONT-conj | (the seed) | the conjecture node itself: real-analytic existence **and** uniqueness |

A small slice of the actual JSON (note: **no `status` field anywhere**):

```jsonc
// state/field.json  (excerpt — 2 of 11 nodes)
{
  "id": "L-composita",
  "kind": "landmark",
  "statement": "The composita recurrence F^Δ(n,k) yields the formal half-iterate series of eˣ−1 exactly (BigInt-exact).",
  "location": {
    "cluster": "formal-series",
    "nearest_landmarks": [
      { "id": "L-fatou", "hops": 1, "relation": "computes-coeffs-of", "semantic_dist": 0.18 },
      { "id": "A-formal", "hops": 1, "relation": "implements", "semantic_dist": 0.12 }
    ],
    "frontier_distance": 0,
    "gap_geometry": "dense well-understood neighborhood",
    "coords": "embed:0x91…  (bridge)  |  assoc-sig: formal,composita,exact"
  },
  "verification": { "checked_cases": "deg ≤ 12 computed & cross-checked", "cross_model_verdict": "AGREE", "baseline_anchored": true },
  "leverage": 4
}
```

```jsonc
{
  "id": "FRONT-conj",
  "kind": "reformulation",
  "statement": "A real-analytic g with g∘g = eˣ−1 exists on a neighborhood of 0, and is unique.",
  "location": {                                    // ← geometry REPLACES any solved/unsolved status
    "cluster": "parabolic-convergence",
    "nearest_landmarks": [
      { "id": "L-fatou",     "hops": 1, "relation": "needs-convergence-of", "semantic_dist": 0.22 },
      { "id": "O-diverge",   "hops": 1, "relation": "threatened-by",        "semantic_dist": 0.20 },
      { "id": "AN-ecalle",   "hops": 2, "relation": "classified-by",        "semantic_dist": 0.31 }
    ],
    "frontier_distance": 2,                         // hops to the nearest VERIFIED baseline (L-composita)
    "gap_geometry": "one missing lemma — convergence/Borel-summability of the formal Fatou coordinate",
    "coords": "embed:0xА3…  |  assoc-sig: parabolic,analytic,unique,Fatou"
  },
  "verification": { "checked_cases": "formal series to deg 12; numerics suggest divergence", "cross_model_verdict": "pending", "baseline_anchored": false },
  "leverage": 9,
  "frontier_tier": "deep-frontier"                  // ← a LOCATION descriptor, NOT "unsolved"
}
```

**Semi-connected edges** are associative links where proximity exceeds a threshold —
cosine-similarity of **embeddings** via the bridge, or **LLM-judged association** as the no-key
fallback. The field is sparse + clustered + bridged, not a tree:

```jsonc
// edges (excerpt)
{ "from":"R-fatou",   "to":"L-abel",      "rel":"specializes", "weight":0.81 }
{ "from":"A-formal",  "to":"L-composita", "rel":"implies",     "weight":0.93 }
{ "from":"O-diverge", "to":"FRONT-conj",  "rel":"bridges",     "weight":0.74 }   // obstruction ↔ frontier
{ "from":"AN-expm1",  "to":"A-parab",     "rel":"analogous",   "weight":0.66 }
```

**Anti-explosion (plan §7.6, R11):** a verifier/DA gate admits a node only if it is non-trivial
and not a near-duplicate (**embedding-dedup**); per-cluster caps and budget governance bound total
growth; the `O-diverge` obstruction node **prunes** the naive "just sum the formal series"
approach before it spawns workers.

---

## Stage 2′ — Position & frontier-map → `state/field.map.md`

For every node the geometer computes its `location`. The "baseline…impossible" ladder is
**reinterpreted as distance-from-verified-baseline geometry**:
`landmark` (verified) → `anchored` → `bridge` → `frontier` → `deep-frontier`. The output is a
**geometry map, not a ranked TODO list**:

```md
# field.map.md — half-iterate of eˣ−1   (generative mode · geometry, not a verdict)

## Verified component (landmarks — baseline_anchored)
- L-composita   formal series F^Δ(n,k) exact to deg 12   [frontier_distance 0]
- L-fatou       formal Fatou coordinate exists           [frontier_distance 0]
- L-abel        Abel-equation reduction                  [frontier_distance 0]

## Anchored / bridge band
- A-formal      order-by-order builder  → implements L-composita        [dist 1, gap: none — computable]
- R-fatou       Fatou-shift-by-½ reformulation → specializes L-abel     [dist 1, gap: none]
- AN-ecalle     Écalle–Voronin moduli (bridge to classification)        [dist 2, gap: cross-domain bridge]

## Frontier
- A-parab       parabolic-iteration approach                            [dist 2, gap: missing technique
                — needs a convergence criterion for the Fatou series]
- O-diverge     divergence obstruction (PRUNES naive summation)         [dist 1 from FRONT-conj]

## Deep-frontier  ← the conjecture itself (a LOCATION, never "unsolved")
- FRONT-conj    real-analytic existence + uniqueness                    [frontier_distance 2]
    neighborhood map:
      • nearest verified landmark : L-composita (2 hops, via A-formal)
      • gap_geometry             : ONE MISSING LEMMA — convergence / Borel-summability
                                   of the formal Fatou coordinate at multiplier 1
      • most promising bridge    : AN-ecalle (Écalle–Voronin) — if the germ's modulus is
                                   computed, uniqueness of a REAL branch may follow
      • computational evidence   : series to deg 12 grows factorially → SUGGESTS divergence,
                                   i.e. likely no real-analytic g, but Borel-summable to a
                                   real-analytic g on sectors (a SHARPER position, still not a verdict)
      • next frontier step       : deep-reasoning verify-loop on "is the deg-n coefficient
                                   bounded by C·n!·ρⁿ?" — anchors a new landmark either way
```

Then the frontier is **explored**: pick nodes maximizing `leverage × reachability ×
uncertainty-reduction`, biased toward **checkable atoms** — here, *compute the deg-13..20
coefficients and test the factorial-growth bound*. Each such step is itself a deep-reasoning
verify-loop (§6.2) that **either anchors a new landmark or sharpens the gap geometry**. It never
returns "solved/unsolved."

---

## What "done" looks like here (the deliverable)

For a hard problem the harness ships the **geometry of the conjecture's location** — continuously,
never a solved/unsolved verdict (plan §7.5):

| Output | Content |
|---|---|
| nearest verified landmarks | `L-composita` (2 hops), `L-fatou`, `L-abel` |
| the gap's **shape** | "one missing lemma — convergence/Borel-summability of the formal Fatou coordinate" |
| most promising bridge | `AN-ecalle` (Écalle–Voronin moduli) toward uniqueness of a real branch |
| computational evidence | factorial coefficient growth to deg 12 → *suggests* divergence (sharper, not final) |
| next frontier step | a verify-loop on the `C·n!·ρⁿ` growth bound, to mint a new landmark |

---

## Why the IRON RULE matters (and how it's honored)

A leaderboard-style harness would have stamped `FRONT-conj` **"impossible / unsolved"** the moment
the series looked divergent — which is both **false** (it's Borel-summable on sectors → a
real-analytic representative *does* exist, just not by naive summation) and **uninformative**.
Instead the field records a **`deep-frontier` location with a neighborhood map**:

- never the word "unsolved" → satisfies R2 (no false defeat, just as we never claim "solved");
- the position is **always informative** — it names the nearest landmark, the exact shape of the
  gap, the bridge most likely to close it, and the next checkable atom;
- the geometry is **advisory and re-derivable**, never asserted as a solved/unsolved claim
  (plan §7 IRON RULE, R12) — if the embedding bridge is down, the same map is rebuilt from
  LLM-judged association signatures, only with coarser coordinates.

> **One line:** the harness's answer to "is there a real-analytic half-iterate of `eˣ−1`?" is not
> *yes*, not *no*, and **never** *unsolved* — it is a **map**: *two hops from verified ground, one
> lemma (convergence/Borel-summability) away, reachable via the Écalle–Voronin bridge, with
> factorial-growth evidence pointing at "divergent series, real-analytic on sectors."*
