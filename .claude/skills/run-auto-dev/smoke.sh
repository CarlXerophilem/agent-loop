#!/usr/bin/env bash
# smoke.sh -- drive the auto-dev skill's executable surface (its 3 hooks) and
# assert each one's documented contract. This skill has no GUI/server/app to
# launch; the hooks ARE the runnable surface, so this script is the driver.
#
# Run (from anywhere):
#   bash .claude/skills/run-auto-dev/smoke.sh
# Windows / Git Bash (recommended interpreter, per the harness's own docs):
#   "C:/Program Files/Git/bin/bash.exe" .claude/skills/run-auto-dev/smoke.sh
#
# Exit 0 iff every non-skipped assertion passed. Network and live-cross-model
# checks SKIP (not FAIL) when arXiv is unreachable or no provider key is set,
# so the script is deterministic on a clean, offline, keyless machine.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../.." && pwd)"
H="${ROOT}/hooks"
TMP="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/runautodev.$$")"; mkdir -p "${TMP}"
trap 'rm -rf "${TMP}"' EXIT
pass=0; fail=0; skip=0
ok(){ printf '  PASS  %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }
sk(){ printf '  SKIP  %s\n' "$1"; skip=$((skip+1)); }

# expect_exit WANT "desc" cmd...   -- run cmd, compare its real exit code
expect_exit(){ local want="$1" desc="$2"; shift 2
  "$@" >"${TMP}/o" 2>"${TMP}/e"; local rc=$?
  if [ "${rc}" = "${want}" ]; then ok "${desc} (exit ${rc})"; else no "${desc} (got ${rc}, want ${want}); out: $(head -1 "${TMP}/o" "${TMP}/e" 2>/dev/null|tr '\n' ' ')"; fi; }
# expect_grep "regex" "desc" cmd...  -- run cmd (exit ignored), assert stdout matches
expect_grep(){ local re="$1" desc="$2"; shift 2
  "$@" >"${TMP}/o" 2>"${TMP}/e"
  if grep -qE "${re}" "${TMP}/o"; then ok "${desc} (matched /${re}/)"; else no "${desc} (no match /${re}/); out: $(head -1 "${TMP}/o")"; fi; }
# no_grep "regex" "desc" cmd...  -- run cmd (exit ignored), assert regex appears in NEITHER stdout nor stderr
no_grep(){ local re="$1" desc="$2"; shift 2
  "$@" >"${TMP}/o" 2>"${TMP}/e"
  if grep -qE "${re}" "${TMP}/o" "${TMP}/e"; then no "${desc} (unexpected /${re}/); out: $(head -1 "${TMP}/o" "${TMP}/e" 2>/dev/null|tr '\n' ' ')"; else ok "${desc} (no /${re}/)"; fi; }
# json_ok "desc" cmd...  -- run cmd, assert its stdout parses as valid JSON (needs PY; else SKIP)
json_ok(){ local desc="$1"; shift
  if [ -z "${PY}" ]; then sk "${desc} -- no python to validate JSON"; return; fi
  "$@" >"${TMP}/o" 2>"${TMP}/e"
  if "${PY}" -c 'import json,sys; json.load(open(sys.argv[1]))' "${TMP}/o" 2>"${TMP}/ej"; then ok "${desc} (valid JSON)"; else no "${desc} (invalid JSON): $(tail -1 "${TMP}/ej" 2>/dev/null)"; fi; }

[ -d "${H}" ] || { echo "FATAL: hooks/ not found at ${H} -- run from inside the auto-dev repo."; exit 3; }
echo "auto-dev smoke harness"
echo "  repo : ${ROOT}"
echo "  bash : $(bash --version 2>/dev/null | head -1)"
PY="$(command -v python3 || command -v python || command -v py || true)"
echo "  py   : ${PY:-MISSING}"
echo "  curl : $(command -v curl || echo MISSING)"

echo "== 1) alphaxiv.sh (arXiv literature bridge) =="
# Degraded paths are key/network-independent -> always asserted:
expect_exit 2 "no subcommand -> usage + exit 2"        bash "${H}/alphaxiv.sh"
expect_exit 2 "unknown subcommand -> exit 2"           bash "${H}/alphaxiv.sh" frobnicate
# Non-numeric max must degrade, never abort with a set -u "unbound variable" at $((MAX+1)).
# Coercion happens before any network call, so this is deterministic offline.
no_grep 'unbound variable' "non-numeric max degrades (no set -u crash)" bash "${H}/alphaxiv.sh" related 1706.03762 foo
# Live arXiv paths: only if reachable.
if bash "${H}/alphaxiv.sh" search "test" 1 >/dev/null 2>&1; then
  expect_grep '[a-z]+\.[A-Z]' "search returns 'id | date | cat | title' lines" bash "${H}/alphaxiv.sh" search "functional equation half-iterate" 3
  expect_grep 'title:'  "paper <id> returns full metadata"  bash "${H}/alphaxiv.sh" paper 1706.03762
  expect_grep '\|'      "related <id> returns neighbour lines" bash "${H}/alphaxiv.sh" related 1706.03762 3
else
  sk "search/paper/related -- arXiv unreachable (offline); degrade paths still pass"
fi

echo "== 2) cross-verify.sh (cross-model verifier bridge) =="
# Key-independent contract: must exit 2 (never block) when unconfigured.
expect_exit 2 "no AUTO_DEV_CROSS_MODEL -> exit 2"  env -u AUTO_DEV_CROSS_MODEL bash "${H}/cross-verify.sh" "is 2+2=4?"
expect_exit 2 "empty prompt -> exit 2"             bash "${H}/cross-verify.sh" ""
expect_exit 2 "unknown provider -> exit 2"         env AUTO_DEV_CROSS_MODEL=llama-9 bash "${H}/cross-verify.sh" "x"
# Optional live call: only if a provider key is present.
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  expect_exit 0 "live deepseek call (key present) -> exit 0" env AUTO_DEV_CROSS_MODEL=deepseek-chat bash "${H}/cross-verify.sh" "Reply with exactly: OK"
else
  sk "live cross-model call -- no provider key in env"
fi

echo "== 3) budget-gate.sh (wall-clock governance) =="
expect_exit 0 "no state/ -> safe no-op exit 0" bash "${H}/budget-gate.sh" "${TMP}/empty"
FH="${TMP}/harness"; mkdir -p "${FH}/state" "${FH}/config"
printf '{ "session_budget_minutes": 300, "warn_at_elapsed_fraction": 0.70, "hard_stop_at_elapsed_fraction": 0.90 }\n' > "${FH}/config/budget.json"
date +%s > "${FH}/state/session.start"
expect_grep '\[budget-gate:ok\]'   "fresh session -> ok"   bash "${H}/budget-gate.sh" "${FH}"
json_ok "budget-gate ok -> valid JSON"                      bash "${H}/budget-gate.sh" "${FH}"
echo $(( $(date +%s) - 240*60 )) > "${FH}/state/session.start"   # 80% of 300m
expect_grep '\[budget-gate:warn\]' "80% elapsed -> warn"   bash "${H}/budget-gate.sh" "${FH}"
json_ok "budget-gate warn -> valid JSON"                    bash "${H}/budget-gate.sh" "${FH}"
echo $(( $(date +%s) - 300*60 )) > "${FH}/state/session.start"   # 100%
expect_grep '\[budget-gate:stop\]' "100% elapsed -> stop"  bash "${H}/budget-gate.sh" "${FH}"
json_ok "budget-gate stop -> valid JSON"                    bash "${H}/budget-gate.sh" "${FH}"

echo "== 4) templates (config + field must be ASCII and valid JSON) =="
# Harness rule (references/loop-setup.md + this skill's Gotchas): state/config JSON must be
# ASCII -- this box's Python defaults to cp936/GBK and chokes on non-ASCII bytes. Operators
# seed config/* by copying these templates, so the templates themselves must comply.
if [ -n "${PY}" ]; then
  for t in "${ROOT}"/templates/config.*.json.tmpl "${ROOT}"/templates/field.node.json.tmpl; do
    [ -f "${t}" ] || continue
    name="templates/$(basename "${t}")"
    if "${PY}" -c 'import json,sys; b=open(sys.argv[1],"rb").read(); assert all(c<128 for c in b),"non-ASCII byte"; json.loads(b.decode("ascii"))' "${t}" 2>"${TMP}/e"; then
      ok "${name} is ASCII + valid JSON"
    else
      no "${name} not ASCII-or-JSON: $(tail -1 "${TMP}/e" 2>/dev/null)"
    fi
  done
else
  sk "template ASCII/JSON check -- no python interpreter resolved"
fi

echo "== 5) hook scripts: shebang + bash -n (syntax) =="
# Every executable hook must start with a #! line and parse cleanly. Catches a syntax
# error or a stripped shebang in any hook before the harness invokes it unattended.
for hk in "${H}"/*.sh; do
  [ -f "${hk}" ] || continue
  name="hooks/$(basename "${hk}")"
  if head -1 "${hk}" | grep -q '^#!' && bash -n "${hk}" 2>"${TMP}/e"; then
    ok "${name}: shebang + bash -n clean"
  else
    no "${name}: bad shebang or syntax: $(tail -1 "${TMP}/e" 2>/dev/null)"
  fi
done

echo "== RESULT: pass=${pass} fail=${fail} skip=${skip} =="
[ "${fail}" -eq 0 ]
