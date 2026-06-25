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
- [ ] Make `references/loop-setup.md` state the cp936/GBK **ASCII rule for state/config**
      explicitly (the smoke suite now enforces ASCII templates; the rationale should be
      one click away from the loop docs).
- [ ] Add `bash -n` lint of `.claude/skills/run-auto-dev/smoke.sh` itself to a meta-check.
- [ ] Add a smoke assertion that `tools/setup-workspace.sh` instantiates CANONICAL paths
      (`config/rubric.json`, not `config/config.rubric.json`) into a temp dir and that every
      written `config/*.json` is ASCII + valid JSON; assert idempotent re-run skips all.

## Done (most recent first)

- [x] Add `tools/setup-workspace.sh`: instantiate the launch inputs from `templates/` with the
      correct `.`->`/` map (`config.rubric.json.tmpl` -> `config/rubric.json`), ASCII+JSON-gate
      every config, idempotent + `--force`; wired into `agents/host_coordinator.md` (phase 0).
      Fixes the manual-strip-only-`.tmpl` footgun (config-key drift). smoke 20/20.
- [x] Unify the Python-interpreter idiom across `hooks/cross-verify.sh` + `hooks/alphaxiv.sh`:
      both now resolve once into `PY` then GUARD each use with `[ -n "${PY}" ]` (dropping the
      misleading `${PY:-python3}` re-try); convention noted in both headers. smoke 20/20.
- [x] Document engines C (GitHub Actions cloud) + D (Claude Agent SDK, local programmatic) in
      `references/loop-setup.md`, bringing it in sync with the shipped `.github/` loop.
- [x] Doc link integrity: smoke section 6 asserts every references/agents/hooks/templates/examples
      path in SKILL.md + references/*.md resolves in-repo (catches dangling refs). Smoke 26 -> 27.
- [x] Harden hook smoke coverage: assert `budget-gate.sh` emits valid JSON at ok/warn/stop, and
      every `hooks/*.sh` has a `#!` shebang + passes `bash -n`. Smoke 20 -> 26.
- [x] Preference-advisor: verified online Bradley-Terry core (`tools/preference-advisor/bt.ts`)
      + passing tests; design + safety rails in `references/preference-advisor.md`.
- [x] ASCII-fold all JSON templates; coerce non-numeric `max` in `alphaxiv.sh`; smoke 13 -> 20.
- [x] Add the run-auto-dev smoke harness to the repo (was untracked).
