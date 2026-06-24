---
name: run-auto-dev
description: Build, run, and smoke-test the auto-dev skill (the agent-loop harness). It has no GUI/server -- its runnable surface is three Git-Bash hooks, and this skill drives them. Use to run / launch / test / verify auto-dev, smoke-test its hooks, search arXiv from the hook (alphaxiv.sh search/paper/related), check the wall-clock budget gate (budget-gate.sh), or drive a cross-model review (cross-verify.sh). Primary driver: .claude/skills/run-auto-dev/smoke.sh under Git Bash on Windows.
---

# run-auto-dev

`auto-dev` is a Claude Code **skill** (an autonomous-session playbook), not an app: there is
no window, server, or REPL to launch. Its only **executable** surface is three Bash hooks in
`hooks/`. You "run" auto-dev by driving those hooks under **Git Bash** (the harness pins
`"C:/Program Files/Git/bin/bash.exe"` on Windows). The driver below exercises all three and
asserts each one's documented contract.

> All paths are relative to the repo root (`<unit>/` = `D:\MATHs\scripts\auto-dev`).

## Prerequisites (verified on this box)

- **Git Bash** (`bash` 5.x, MSYS). On Windows invoke hooks with the explicit interpreter
  `"C:/Program Files/Git/bin/bash.exe"`.
- **A Python 3 under any name** -- `python3`, `python`, or `py`. This box has only
  `python` (3.14.2 at `C:\Python314`) and `py`; `python3` is **absent**. The hooks resolve
  all three names, so no install is needed. (`curl`, `awk`, `sed` are also required and ship
  with Git Bash / the system.)
- **Optional**: a cross-model provider key in the environment (`DEEPSEEK_API_KEY`,
  `OPENAI_API_KEY`, or `GOOGLE_AI_API_KEY`) for a *live* `cross-verify.sh` call. Without one,
  the hook degrades cleanly (exit 2) -- it never blocks.

## Build

None -- nothing compiles. The only "build" step is making sure you are on the branch that
carries the arXiv bridge: `alphaxiv.sh` + `references/alphaxiv-bridge.md` live **only on
`auto-dev/debug-and-alphaxiv` (HEAD cc3990c), not on `main`**.

```bash
git -C /d/MATHs/scripts/auto-dev branch --show-current   # expect: auto-dev/debug-and-alphaxiv
ls /d/MATHs/scripts/auto-dev/hooks                        # expect: alphaxiv.sh budget-gate.sh cross-verify.sh
```

## Run (agent path) -- the driver

```bash
bash .claude/skills/run-auto-dev/smoke.sh
```

On Windows, equivalently:

```bash
"C:/Program Files/Git/bin/bash.exe" .claude/skills/run-auto-dev/smoke.sh
```

It runs 20 assertions and exits 0 iff all pass. The 3 live-arXiv and 1 live-cross-model checks
**SKIP** (not fail) when offline / keyless: a clean, offline, keyless box reports `pass=16
skip=4`; this box (online, key present) reports `pass=20 skip=0`. Last line looks like:

```
== RESULT: pass=20 fail=0 skip=0 ==
```

### Driving the hooks directly (what the driver runs)

**arXiv literature bridge** -- one paper per line as `id | date | category | title`:

```bash
bash hooks/alphaxiv.sh search "functional equation half-iterate" 3
bash hooks/alphaxiv.sh paper 1706.03762        # -> title: Attention Is All You Need ...
bash hooks/alphaxiv.sh related 1706.03762 3    # neighbours by category + title terms
```

(The official **alphaXiv MCP server** -- `https://api.alphaxiv.org/mcp/v1`, set
`ALPHAXIV_MCP_URL` -- is the documented *primary*, reached by agents over MCP; this shell
hook is the no-key arXiv fallback that hits `export.arxiv.org` directly.)

**Cross-model verifier** -- prompt by arg or stdin; exits 2 when unconfigured:

```bash
echo "Reply with exactly: OK" | AUTO_DEV_CROSS_MODEL=deepseek-chat bash hooks/cross-verify.sh   # live, needs DEEPSEEK_API_KEY
bash hooks/cross-verify.sh ""                                                                    # -> CROSS_MODEL_AVAILABLE=none (empty prompt); exit 2
```

**Wall-clock budget gate** -- a Stop/PreToolUse hook; safe no-op unless both
`state/session.start` (epoch seconds) and `config/budget.json` exist. Pass the harness root
as `$1` (or set `$AUTO_DEV_HOME`):

```bash
bash hooks/budget-gate.sh /path/with/no/state          # -> (no output); exit 0  (safe no-op)
# with state present it emits, e.g.:
# {"systemMessage":"[budget-gate:warn] 80% elapsed: shed T2/T3, finish open T0/T1 only"}
```

## Run (human path)

There isn't a separate one. A human/operator runs the *whole harness* via the parent skill's
`/auto-dev` command (see the repo-root `SKILL.md`); the three hooks above are normally invoked
*by* the harness's agents, not by hand. This skill exists to **verify the hooks** in isolation.

## Gotchas (all hit while building this)

- **`python3` is absent on Windows.** Only `python`/`py` exist here. A hook that hardcodes
  `python3` silently degrades (this was a real, fixed bug in `cross-verify.sh`; it now resolves
  `python3 || python || py`). If you add a hook, mirror that resolution.
- **Non-numeric `max` arg is coerced to the default (was a crash).** `bash hooks/alphaxiv.sh related
  1706.03762 foo` used to abort with `line 151: foo: unbound variable` (the `set -u` x `$((MAX+1))`
  interaction); the hook now coerces a non-numeric/empty `max` to `ALPHAXIV_MAX` (default 8) before
  any arithmetic, so it returns results (or degrades to exit 2 offline) without crashing. The smoke
  test asserts the `unbound variable` string never appears.
- **State must be ASCII.** This box's Python defaults to the **GBK** codec; a non-ASCII byte
  (e.g. an em-dash) in `loop-state.local.json` / any `state/*.json` breaks `json.load`. Keep
  `state/` ASCII (the harness's own `references/loop-setup.md` warns this). The shipped
  `templates/*.json.tmpl` are kept ASCII for the same reason — smoke test section 4 enforces it,
  since operators seed `config/*` by copying those templates.
- **Degraded == exit 2, never a hang.** Every offline / no-key / bad-arg path on `alphaxiv.sh`
  and `cross-verify.sh` returns `*_AVAILABLE=none ...` and exit 2 by design ("never block on
  bridge failure").
- **`budget-gate.sh` prints nothing without state.** That is the documented safe no-op (exits
  0) so it never clobbers a sibling Stop hook -- not a failure.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `alphaxiv.sh` returns the default count, not yours | A non-numeric/empty `max` is coerced to the default (8); pass an integer for an exact count. |
| `cross-verify.sh` prints raw JSON, not text | No Python 3 resolved; ensure `python3`/`python`/`py` is on PATH. |
| `cross-verify.sh` exits 2 with `(no DEEPSEEK_API_KEY)` | Export the key, or accept the same-family fallback -- it is meant to degrade. |
| `smoke.sh` -> `FATAL: hooks/ not found` | Run it from inside the repo; `ROOT` is derived from the script path, so don't relocate `smoke.sh` away from `.claude/skills/run-auto-dev/`. |
| `alphaxiv.sh` always `network/arxiv unreachable` | `export.arxiv.org` blocked; the alphaXiv MCP primary still works for agents. |

## The driver

`.claude/skills/run-auto-dev/smoke.sh` -- the harness above. It resolves the repo root from
its own location, builds a throwaway fake harness in `mktemp -d` for the budget-gate cases,
and cleans up on exit.
