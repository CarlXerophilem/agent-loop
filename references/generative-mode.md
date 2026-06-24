# generative-mode.md — Generative / Research mode

> **Status:** scaffold · Mirrors **plan §7** (refinement #5). Kept **separate** from engineering mode — not unified. Phases 3–6 are shared; only phases 1–2 change.

## When it's selected

A launch-time classifier reads `GOAL.md` (rules in `config/mode.json`). Generative mode is picked when the GOAL is a **terse hard statement** — a conjecture, an open problem, a one-line "prove / characterize X" with **no obvious decomposition**. (Engineering mode is the default, for GOALs that decompose into concrete TODOs.)

## Why generative

A one-line conjecture conceals a vast latent structure. The harness **unfolds** the seed generatively into an associative graph whose geometry mirrors the LLM's representational basis ("approaching the basis of the LLM framework"), then works **inward from verifiable atoms** — without ever labeling anything "unsolved."

---

## Stage 1′ — Generate the field

Divergent generator agents (`AGT`, effort `xhigh`, **diverse personas**, background) unfold the seed into nodes:

| Node kind | What it captures |
|---|---|
| `landmark` | a verified baseline fact |
| `lemma` | a decomposition / sub-claim |
| `approach` | a candidate technique |
| `analogy` | a cross-domain correspondence |
| `obstruction` | a known barrier (prunes dead approaches) |
| `reformulation` | an equivalent restatement |

**Semi-connected edges** are associative links where proximity exceeds a threshold — embeddings cosine-similarity (via the bridge), or LLM-judged association as the no-key fallback. See `embeddings-bridge.md` and `knowledge-field-schema.md`. The field is **sparse + clustered + bridged, not a tree.** Data model: `state/field.json`.

---

## Stage 2′ — Position & frontier-map

For every node compute its **`location` geometry** (cluster, nearest verified landmarks, frontier distance, gap shape, coords). Then explore the **frontier**: pick nodes maximizing

```
leverage × reachability × uncertainty-reduction
```

biased toward **checkable atoms** (small-case computation, cross-model-verified steps) that mint `baseline_anchored` landmarks and grow the verified component outward. The old "baseline…impossible" ladder reinterprets as **distance-from-verified-baseline geometry**:

```
landmark (verified) → anchored → bridge → frontier → deep-frontier
```

Output is `state/field.map.md` — the geometry/frontier map, **NOT** a ranked TODO list.

---

## Win condition / deliverable

> **IRON RULE — never "unsolved"; position by geometry.** A node is **never** stamped `unsolved` / `impossible` / `failed`. The harness ships the **geometry of the problem's location**: the neighborhood, nearest verified landmarks, the gap's shape, the most promising bridges, and any computational evidence — **continuously, never a "solved/unsolved" verdict**. The far tier is `deep-frontier`: a positional descriptor + neighborhood map, not a defeat. This also satisfies the anti-lying rule (plan R2): we never claim "solved" and never write "unsolved" — we write the truthful **position**, which is always informative.

Each promising frontier step is itself a deep-reasoning verify-loop (`deep-reasoning-loop.md`) that either **anchors a new landmark** or **sharpens the gap geometry**.

---

## Anti-explosion (pruning, plan R11)

Generation is **divergent then convergent**:

- a **verifier / DA gate** admits a node only if non-trivial and not a near-duplicate (**embedding-dedup**, `embeddings-bridge.md`);
- **per-cluster node caps**;
- **budget governance** bounds total field growth;
- **obstruction nodes** prune dead approaches.

<!-- expand here: classifier rule examples (engineering vs generative); generator persona set; the frontier-scoring formula expanded; field.map.md section layout -->
