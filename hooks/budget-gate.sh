#!/usr/bin/env bash
# budget-gate.sh — auto-dev wall-clock governance hook (Stop / PreToolUse).
#
# HONEST PROXY: gauges ELAPSED WALL-CLOCK against config/budget.json targets.
# It does NOT read account usage (remaining usage is not machine-readable from
# inside a session). Emits a {"systemMessage": "..."} on stdout and exits 0.
# Safe no-op if state is missing, so it never breaks the loop or sibling hooks.
#
# Resolve harness root: arg $1, or $AUTO_DEV_HOME, or the script's parent dir.
# state/session.start must hold EPOCH SECONDS (write with: date +%s > session.start).
#
# Windows: invoke via an explicit git-bash, e.g.
#   "C:/Program Files/Git/bin/bash.exe" hooks/budget-gate.sh /abs/harness
set -u

HARNESS="${1:-${AUTO_DEV_HOME:-}}"
if [ -z "${HARNESS}" ]; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  HARNESS="$(cd "${HERE}/.." && pwd)"
fi
START_FILE="${HARNESS}/state/session.start"
BUDGET_FILE="${HARNESS}/config/budget.json"

emit() { printf '{"systemMessage":"[budget-gate:%s] %s"}\n' "$1" "$2"; }

[ -f "${START_FILE}" ]  || exit 0
[ -f "${BUDGET_FILE}" ] || exit 0

num() { # numeric JSON field $1 from budget.json, default $2 (no jq dependency)
  local v
  v="$(grep -oE "\"$1\"[[:space:]]*:[[:space:]]*[0-9.]+" "${BUDGET_FILE}" 2>/dev/null \
        | grep -oE '[0-9.]+' | head -n1)"
  [ -n "${v}" ] && printf '%s' "${v}" || printf '%s' "$2"
}

START="$(tr -dc '0-9' < "${START_FILE}" | head -c 20)"
[ -n "${START}" ] || exit 0
NOW="$(date +%s)"
MIN="$(num session_budget_minutes 300)"
WARN="$(num warn_at_elapsed_fraction 0.70)"
STOP="$(num hard_stop_at_elapsed_fraction 0.90)"

OUT="$(awk -v now="${NOW}" -v start="${START}" -v min="${MIN}" -v warn="${WARN}" -v stop="${STOP}" 'BEGIN{
  total=min*60; if(total<=0){print "ok|elapsed unknown"; exit}
  f=(now-start)/total; pf=int(f*100+0.5);
  if(f>=stop)      printf("stop|%d%% elapsed: hard-stop - write HANDOFF, finish open T0, then exit", pf);
  else if(f>=warn) printf("warn|%d%% elapsed: shed T2/T3, finish open T0/T1 only", pf);
  else             printf("ok|%d%% elapsed: budget ok, continue", pf);
}')"
LEVEL="${OUT%%|*}"
MSG="${OUT#*|}"
emit "${LEVEL}" "${MSG}"
exit 0
