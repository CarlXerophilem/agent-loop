# Running the auto-dev loop 24/7 on GitHub Actions

This makes the auto-dev self-improvement loop run on GitHub's infrastructure on a
schedule — **no laptop needs to stay open**. Three workflows:

| Workflow | File | Trigger | Cost | What it does |
|---|---|---|---|---|
| **canary** | `workflows/loop-canary.yml` | manual | $0 (no secret) | Proves the plumbing: runner runs the smoke suite, and a PR can be opened/closed via the built-in token. |
| **loop (improve)** | `workflows/auto-loop.yml` | daily + manual | API/subscription tokens | One small, smoke-gated improvement per run → opens a PR for review. |
| **smoke** | `workflows/smoke.yml` | push/PR to `main` | $0 | Runs the 20-assertion smoke suite as a status check on `main` and human PRs. |

## One-time setup

1. **Enable Actions** for the repo (Settings → Actions → General → Allow all actions).
2. **Allow Actions to open PRs** (Settings → Actions → General → Workflow permissions →
   check *"Allow GitHub Actions to create and approve pull requests"*). Without this,
   `gh pr create` returns 403 even though the `permissions:` block is correct — a common
   silent blocker.
3. **Protect `main` (required before going 24/7)** — Settings → Branches → add a rule for
   `main`: require a PR before merging and require the `smoke` status check. This is the real
   backstop: it makes it impossible for an unattended run to land anything on `main` without a
   green smoke run and your review, regardless of token scope.
4. **Add ONE auth secret** (Settings → Secrets and variables → Actions → *Secrets*):
   - `CLAUDE_CODE_OAUTH_TOKEN` — bills your **Claude subscription**. Generate locally with
     `claude setup-token` and paste the value. (Cheapest if you have Max; subject to your
     subscription's usage limits, and the token must be regenerated when it eventually expires.)
   - **or** `ANTHROPIC_API_KEY` — pay-per-token API billing from console.anthropic.com.
     (No expiry; unmetered reliability for unattended runs.)

   Set only one. `auto-loop.yml` passes both inputs; the action uses the OAuth token if
   present, else the API key.

## Ramp (the "small experiment first" path)

1. **Canary** — Actions tab → *auto-dev loop (canary)* → **Run workflow**. Confirm it goes
   green. This validates the runner, the smoke suite, and the PR mechanism for **$0** and
   needs no secret. *(The `workflow_dispatch` button only appears once this file is on the
   default branch `main`.)*
2. **Manual loop run** — after adding the secret, Actions tab → *auto-dev loop (improve)* →
   **Run workflow**. This runs the full loop once end-to-end; if it finds an improvement it
   opens a PR (smoke-gated). Review it.
3. **Go 24/7** — Settings → Secrets and variables → Actions → *Variables* → add
   `LOOP_ENABLED = true`. Scheduled runs (daily, 09:07 UTC) now execute. The manual button keeps
   working regardless of this variable.

## Pause / stop

- **Pause the schedule:** set `LOOP_ENABLED = false` (no code change). Scheduled runs become
  no-ops; manual dispatch still works.
- **Stop entirely:** Actions tab → *auto-dev loop (improve)* → ⋯ → **Disable workflow**.
- GitHub auto-disables a scheduled workflow after **60 days of repo inactivity** — a merge or
  push (e.g. merging the loop's PRs) resets that clock.

## Cost & safety notes

- Each run is short and bounded: `--max-turns 12`, `timeout-minutes: 30`, and
  `concurrency` prevents overlapping runs. The loop opens **no PR** when it finds nothing
  to change (no empty-PR spam).
- The loop **never merges to `main`** — it only opens PRs for your review.
- PRs opened by the loop use the built-in `GITHUB_TOKEN`, so they do **not** re-trigger the
  `smoke` workflow (GitHub's anti-recursion rule). That's why `auto-loop.yml` runs the smoke
  suite itself and **hard-gates** on it before opening a PR. For an auto-running check on the
  bot's PRs too, install a GitHub App and pass its token as `github_token` (optional, later).
- The Claude step runs with an explicit `--allowedTools` allowlist (edit/read/grep + `bash`
  and `python` only — no `git`/`gh`/`curl`), so the privileged git/PR work happens only in the
  deterministic workflow step, not inside the agent.
- `main` protection (setup step 3) is **required**, not optional — it's the hard backstop that
  makes an unattended push to `main` impossible even if the agent misbehaves.

### Troubleshooting

- **Loop step fails with "non-human actor":** the action's human-actor check tripped on a
  scheduled run. `allowed_bots: "*"` is already set in `auto-loop.yml` to prevent this; if you
  removed it, restore it.
- **`gh pr create` 403 / "not allowed to create pull request":** enable setup step 2.
- **Scheduled runs never fire:** confirm `LOOP_ENABLED=true` (a *variable*, not a secret), that
  Actions are enabled, and that the repo has had activity in the last 60 days.

## Alternative (not used here)

Claude Code's own `/schedule` "routines" run in Anthropic's cloud (also laptop-independent)
and bill your subscription, with a 2-minute setup. We chose GitHub Actions for native repo
integration, the free `smoke` gate, and the on/off variable switch.
