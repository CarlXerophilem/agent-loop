# auto-loop backlog

Small, verifiable improvement candidates for the scheduled loop (`auto-loop.yml`).
The loop prefers the top **unchecked** item; each run does ONE and must keep the
smoke suite green. Keep items small. This file is tracked, so it persists across
runs (unlike the local-only `loop-state.local.json`).

## Candidates

- [ ] Wire the **preference-advisor** suggestions into the loop at the 3 phases
      (brainstorm / initial-selection / final-review), OFF by default behind a flag. The
      numeric core is done + tested; see `references/preference-advisor.md` and
      `tools/preference-advisor/`. Advisor is suggestion-only; the rubric/human still decide.
- [ ] Implement the SCAFFOLD stubs in `tools/preference-advisor/` (advisor.ts brainstorm +
      final-review LLM-judge; ingest.ts `gh` PR-outcome fetch + Reflexion rewrite of
      `state/preferences.md`) using the mature designs cited in its README.
- [ ] Add the Claude **Agent SDK** as a 4th local loop driver in `references/loop-setup.md`
      (note: SDK auth is `ANTHROPIC_API_KEY` only -- no subscription OAuth).
- [ ] Add a smoke assertion that `budget-gate.sh` emits **valid JSON** at ok/warn/stop
      (pipe each through a JSON parser; today only the `[budget-gate:...]` substring is checked).
- [ ] Add a smoke assertion that every `hooks/*.sh` passes `bash -n` (syntax) and starts
      with a `#!` shebang line.
- [ ] Add a smoke assertion that `references/*.md` internal links (`` `file.md` `` / relative
      paths) resolve to files that exist in the repo (catch dangling references early).
- [ ] Make `references/loop-setup.md` state the cp936/GBK **ASCII rule for state/config**
      explicitly (the smoke suite now enforces ASCII templates; the rationale should be
      one click away from the loop docs).
- [ ] Add `bash -n` lint of `.claude/skills/run-auto-dev/smoke.sh` itself to a meta-check.

## Done (most recent first)

- [x] Unify the Python-interpreter idiom across `hooks/cross-verify.sh` + `hooks/alphaxiv.sh`:
      both now resolve once into `PY` then GUARD each use with `[ -n "${PY}" ]` (dropping the
      misleading `${PY:-python3}` re-try); convention noted in both headers. smoke 20/20.
- [x] Preference-advisor: verified online Bradley-Terry core (`tools/preference-advisor/bt.ts`)
      + passing tests; design + safety rails in `references/preference-advisor.md`.
- [x] ASCII-fold all JSON templates; coerce non-numeric `max` in `alphaxiv.sh`; smoke 13 -> 20.
- [x] Add the run-auto-dev smoke harness to the repo (was untracked).
