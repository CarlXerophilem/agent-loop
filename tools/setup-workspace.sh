#!/usr/bin/env bash
# setup-workspace.sh -- instantiate an auto-dev workspace from templates/ into a project.
#
# WHY THIS EXISTS
#   templates/ is FLAT, but the live workspace is NESTED. Each template encodes its
#   destination with '.' as the path separator, e.g.
#       templates/config.rubric.json.tmpl   ->   <project>/config/rubric.json
#       templates/inbox.LAUNCH.md.tmpl       ->   <project>/inbox/LAUNCH.md
#   Naively stripping only the '.tmpl' suffix yields config/config.rubric.json, which
#   silently breaks the 25+ references to config/rubric.json across the harness (the
#   "config-key drift / missing templates" bug class). This script applies the correct
#   map ONCE, idempotently, and ASCII+JSON-validates every config it writes (the cp936/GBK
#   box rule: state/config files must be pure-ASCII valid JSON, references/loop-setup.md).
#
# WHAT IT WRITES
#   Only the launch INPUTS the host-coordinator reads at phase 0 (agents/host_coordinator.md):
#   the five config/*.json, GOAL.md, and inbox/LAUNCH.md. It deliberately does NOT
#   pre-create runtime/derived artifacts -- state/HANDOFF.md (host writes it at hard-stop),
#   state/field.json (the field generator emits it), or the blackboard (append-only at
#   runtime). field.node.json.tmpl / blackboard-entry.tmpl are schema/format examples, not
#   1:1 live files, so they are intentionally absent from the map below.
#
# Usage:
#   setup-workspace.sh <project-dir> [--force]
#     --force   overwrite existing destination files (default: skip, never clobber edits)
# Windows: invoke via an explicit git-bash, e.g.
#   "C:/Program Files/Git/bin/bash.exe" tools/setup-workspace.sh "D:/MATHs/math 4890 LieML"
# Exit codes: 0 ok; 2 bad args/env; 3 missing template; 4 a written config is not ASCII+JSON.
set -u

SKILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # repo root (this script lives in tools/)
TPL="${SKILL_ROOT}/templates"
DEST="${1:-}"
FORCE="${2:-}"
# Shared interpreter idiom (see hooks/cross-verify.sh, hooks/alphaxiv.sh): resolve once,
# then GUARD each use with `[ -n "${PY}" ]`. Without an interpreter the JSON gate is skipped
# (the smoke suite still enforces ASCII+JSON on the templates themselves).
PY="$(command -v python3 || command -v python || command -v py || true)"

[ -n "${DEST}" ] || { echo "setup-workspace: need a target project dir" >&2; exit 2; }
[ -d "${TPL}" ]  || { echo "setup-workspace: templates/ not found at ${TPL}" >&2; exit 2; }

# template-basename -> destination (relative to the project dir). The '.'->'/' mapping is
# spelled out here so it is unambiguous and reviewable, not reconstructed by a clever sed.
MAP="
config.agent-defaults.json.tmpl   config/agent-defaults.json
config.budget.json.tmpl           config/budget.json
config.main_track.json.tmpl       config/main_track.json
config.mode.json.tmpl             config/mode.json
config.rubric.json.tmpl           config/rubric.json
GOAL.md.tmpl                      GOAL.md
inbox.LAUNCH.md.tmpl              inbox/LAUNCH.md
"

written=0; skipped=0; validated=0
# Fed via heredoc (NOT a pipe) so the counters survive -- a `... | while read` runs the loop
# body in a subshell and would discard them.
while read -r tpl rel; do
  [ -n "${tpl}" ] || continue
  src="${TPL}/${tpl}"
  dst="${DEST}/${rel}"
  [ -f "${src}" ] || { echo "  MISS  template not found: ${tpl}" >&2; exit 3; }
  mkdir -p "$(dirname "${dst}")"
  if [ -f "${dst}" ] && [ "${FORCE}" != "--force" ]; then
    echo "  skip  ${rel} (exists; pass --force to overwrite)"; skipped=$((skipped+1)); continue
  fi
  cp "${src}" "${dst}"; echo "  write ${rel}"; written=$((written+1))
  case "${rel}" in
    config/*.json)
      if [ -n "${PY}" ]; then
        "${PY}" -c "import json,sys; json.load(open(sys.argv[1],encoding='ascii'))" "${dst}" \
          || { echo "  FAIL  ${rel} is not ASCII + valid JSON" >&2; exit 4; }
        validated=$((validated+1))
      fi
      ;;
  esac
done <<EOF
${MAP}
EOF

echo "setup-workspace: wrote=${written} skipped=${skipped} json_validated=${validated} -> ${DEST}"
echo "next: edit GOAL.md (Statement + mode_hint + success criteria) and inbox/LAUNCH.md, then launch the host-coordinator."
