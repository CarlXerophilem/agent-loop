# auto-loop backlog

Small, verifiable improvement candidates for the scheduled loop (`auto-loop.yml`).
The loop prefers the top **unchecked** item; each run does ONE and must keep the
smoke suite green. Keep items small. This file is tracked, so it persists across
runs (unlike the local-only `loop-state.local.json`).

## Candidates

- [ ] Add a smoke assertion that `budget-gate.sh` emits **valid JSON** at ok/warn/stop
      (pipe each through a JSON parser; today only the `[budget-gate:...]` substring is checked).
- [ ] Add a smoke assertion that every `hooks/*.sh` passes `bash -n` (syntax) and starts
      with a `#!` shebang line.
- [ ] Add a smoke assertion that `references/*.md` internal links (`` `file.md` `` / relative
      paths) resolve to files that exist in the repo (catch dangling references early).
- [ ] Unify the Python-interpreter resolution style across `hooks/alphaxiv.sh` and
      `hooks/cross-verify.sh` (both work; one guards with `[ -n "$PY" ]`, the other uses
      `${PY:-python3}`) -- pick one idiom and note it.
- [ ] Make `references/loop-setup.md` state the cp936/GBK **ASCII rule for state/config**
      explicitly (the smoke suite now enforces ASCII templates; the rationale should be
      one click away from the loop docs).
- [ ] Add `bash -n` lint of `.claude/skills/run-auto-dev/smoke.sh` itself to a meta-check.

## Done (most recent first)

- [x] ASCII-fold all JSON templates; coerce non-numeric `max` in `alphaxiv.sh`; smoke 13 -> 20.
- [x] Add the run-auto-dev smoke harness to the repo (was untracked).
