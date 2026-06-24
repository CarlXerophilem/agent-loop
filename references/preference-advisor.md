# preference-advisor — a tiny, behavior-aligned SUGGESTION provider

> **Scope (hard rule).** The advisor only *suggests*. It never decides, never edits
> files, never opens/merges PRs, and never touches the objective gates (smoke suite,
> governance). It is an **AI-in-the-loop** component: you (and the existing rubric in
> `references/rubric.md`) keep control; the advisor adds one learned signal — "based on
> what you've accepted before, here's what I'd lean toward, and why." If it has no signal
> (cold start), it stays silent and the loop behaves exactly as today.

It learns from the behavior you already produce: every loop PR ends up **merged**,
**merged-after-your-edits**, or **closed**. Those outcomes are implicit pairwise
preferences. The advisor turns them into a calibrated nudge at three decision points.

## Where it plugs in (only these three phases)

| Phase | auto-dev mapping | Advisor input (kept simple) | Advisor output (suggestion only) |
|---|---|---|---|
| **Brainstorm** | phase 1 DISCOVER / backlog generation | current context + `preferences.md` | a few candidate choices it thinks you'd value (expands options; does not pick) |
| **Initial (selection)** | phase 2 PRIORITIZE | the candidate **choices**, or a **choice-difference** (A vs B) | a suggested ranking + one-line rationale per item; the rubric/you still choose |
| **Final review** | pre-PR / deep-reasoning verify | the near-final plan or diff | predicted "accept-as-is vs you'll-tweak-it" + the specific tweak it expects |

Nothing else in the loop changes. If the advisor is removed, phases 1/2/verify run as before.

## The "tiny learning machine"

Two cooperating parts — neither is a trained neural net (you have only a few data points
per week; heavy models overfit):

1. **Numeric core — online Bradley-Terry over choice-differences.** Each candidate is a
   small feature vector `x` (e.g. `is_doc, is_robustness, is_test, small, area_hooks,
   area_templates, touches_gate`). Preference probability is
   `P(A > B) = sigmoid(w . (x_A - x_B))` — i.e. the model reads the **difference** between
   two choices, which is exactly the "choice difference" signal. One SGD step per observed
   preference (L2-regularized for the sparse regime). This is the same Bradley-Terry math
   that underlies RLHF reward models; the weight vector `w` is directly interpretable
   ("you reward small robustness fixes; you penalize template restructures").
   *Verified*: cold-start agreement ~0.50 (no signal -> defers), ~0.86 after 25 prefs,
   ~0.94 / cosine 0.98 to the true taste after ~400 — fast and honest on little data.

2. **Verbal core — LLM-as-judge + Reflexion memory.** `preferences.md` is a short,
   human-readable rubric the loop rewrites each cycle from the acceptance history (a
   Reflexion-style "text gradient"). At selection/review an LLM-judge reads it and produces
   the rationale and catches things the feature vector can't encode. The numeric score
   ranks; the judge explains and sanity-checks.

The two are combined, not averaged blindly: BT gives the calibrated ordering; the judge can
flag "low confidence / not enough history" so the advisor abstains rather than guess.

## Data files (all human-readable; live under `state/`)

- `state/acceptance-log.jsonl` — one line per past proposal:
  `{"ts":..., "run":..., "area":"hooks", "type":"robustness", "size":"small",
    "features":[...], "outcome":"merged|edited|closed"}`. Populated by reading PR outcomes
  (`gh pr list --state merged|closed`). ASCII only (cp936/GBK rule, see `loop-setup.md`).
- `state/preferences.md` — the verbal rubric (Reflexion memory). Injected into loop prompts.
- `state/advisor-weights.json` — the BT weight vector + feature names. ASCII, flat JSON.

## Turning behavior into pairwise preferences

- `merged` (unedited) > `closed` for the same round's candidates -> a positive pair.
- `edited-then-merged` = weak positive for the *type*, plus the diff of your edit is a
  strong signal for `preferences.md` ("you always tighten commit messages / prefer X").
- The candidate you (or the rubric) picked > the candidates not picked -> pairwise prefs
  even before merge. This is the "choice difference" at selection time.

## Safety rails (non-negotiable)

1. **Advisory only.** The advisor's output is text/score consumed by the planner or shown
   to you. It has no write tools. Decisions remain with the rubric + your PR review.
2. **Keep objective and subjective separate** (the 3-tier split): the **smoke suite** stays
   the hard correctness gate; the advisor only influences *which valid option* to prefer.
   It can never relax or edit the gate to raise its own "accept" score (anti-reward-hacking).
3. **No self-dealing.** The learning may update `preferences.md` / `advisor-weights.json` /
   backlog ranking — never the smoke suite, hooks' contracts, or this file's safety rails.
4. **Honest abstention.** Below a confidence/history threshold it says "no strong signal"
   and defers. Cold start = silent. This is why it can't do harm before it has learned.
5. **Bounded memory.** `preferences.md` is capped (a rubric, not a transcript); old log
   lines age out so one stale habit can't dominate.

## Maturity — designs this is built on (not invented here)

- **Bradley-Terry / pairwise preference learning** — the choice-difference core and RLHF
  reward-model lineage. (Towards Data Science intro; emergentmind BT topic.)
- **LLM-as-a-judge + panel/meta-judge** and **calibration against human corrections**
  (LangSmith *Align Evals*: collect corrections -> few-shot -> track agreement).
- **AI-in-the-loop vs human-in-the-loop** framing — humans keep control, AI supports the
  decision (arXiv 2511.10865 patch-evaluation framework).
- **Reflexion** (verbal reinforcement; self-critique stored as memory) for `preferences.md`
  (noahshinn/reflexion; arXiv "A Self-Improving Coding Agent" 2504.15228).

URLs are listed in `tools/preference-advisor/README.md`.

## Status

Phase-1 target: **suggestion provider only**, at the three phases above. The numeric core is
implemented and unit-tested; the LLM-judge/SDK wiring is a scaffold under
`tools/preference-advisor/` (TypeScript, `@anthropic-ai/claude-agent-sdk`). It is OFF by
default and integrates with the loop only when explicitly enabled.
