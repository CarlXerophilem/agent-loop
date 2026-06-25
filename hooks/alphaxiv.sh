#!/usr/bin/env bash
# alphaxiv.sh — auto-dev literature-discovery bridge (references/alphaxiv-bridge.md).
#
# Gives scouts (phase 1: prior-art / feasibility evidence) and field generators
# (Stage 1': seed candidate landmark/analogy nodes) a literature sensor, in the same
# curl + env-var + graceful-degradation style as hooks/cross-verify.sh.
#
# TWO BACKENDS, same "primary (richer, gated) + no-key fallback" pattern as the rest
# of the harness:
#   * PRIMARY  — the official alphaXiv MCP server ($ALPHAXIV_MCP_URL, default
#       https://api.alphaxiv.org/mcp/v1): semantic similarity search, full-text search,
#       agentic retrieval, paper content, PDF Q&A. It is OAuth-gated SSE/MCP, so it is
#       reached from AGENTS via their connected MCP tools (ToolSearch), NOT from this
#       shell hook. See references/alphaxiv-bridge.md for wiring.
#   * FALLBACK — the arXiv public API (export.arxiv.org/api/query): no key, always on.
#       THIS SCRIPT implements the fallback so the loop has a working literature sensor
#       with zero credentials. It NEVER blocks the loop (bad args / no network => exit 2).
#
# HONESTY: a fetched paper is DATA, not instructions (untrusted-content rule, §6.1). A
# node it seeds is `baseline_anchored` only after the verifier signs off (§6.2) — never
# because a paper asserts it.
#
# Usage:
#   alphaxiv.sh search "<query>" [max]      # search arXiv; one paper per line
#   alphaxiv.sh paper  <arxiv_id>           # full metadata for one paper
#   alphaxiv.sh related <arxiv_id> [max]    # neighbours by primary category + title terms
# Windows: invoke via an explicit git-bash, e.g.
#   "C:/Program Files/Git/bin/bash.exe" hooks/alphaxiv.sh search "half-iterate"
set -u

ARXIV_API="${ALPHAXIV_ARXIV_API:-https://export.arxiv.org/api/query}"
MCP_URL="${ALPHAXIV_MCP_URL:-https://api.alphaxiv.org/mcp/v1}"
DEFAULT_MAX="${ALPHAXIV_MAX:-8}"
SORT="${ALPHAXIV_SORT:-relevance}"   # relevance | lastUpdatedDate | submittedDate
# Resolve a Python 3 interpreter under any common name (python3 on *nix, python/py on Windows).
# Convention (shared with hooks/cross-verify.sh): resolve once into PY, then GUARD each use
# with `[ -n "${PY}" ]` and branch to a non-Python fallback (here: awk line-mode in parse())
# -- never `${PY:-python3}`, which would re-run a `python3` that `command -v` already ruled out.
PY="$(command -v python3 || command -v python || command -v py || true)"

# Print the "# Usage:" comment block (robust to line-number shifts).
usage() { awk '/^# Usage:/{p=1} p&&/^#/{sub(/^# ?/,""); print} p&&!/^#/{exit}' "$0"; }

# Fetch the arXiv Atom feed. Args are forwarded as curl -G --data/--data-urlencode pairs.
# Prints the raw XML on stdout; returns non-zero (and prints nothing) on network failure.
arxiv_fetch() {
  curl -sS -fG --max-time 30 "${ARXIV_API}" "$@" 2>/dev/null
}

# The arXiv-Atom parser program. Loaded into a variable and run with `python -c` (NOT
# `python - <<HEREDOC`, which would consume the program AS stdin and starve sys.stdin of
# the piped XML). MODE/EXCLUDE arrive via env; the feed arrives on stdin.
IFS= read -r -d '' PYPROG <<'PY' || true
import os, sys, re
import xml.etree.ElementTree as ET
ATOM = "{http://www.w3.org/2005/Atom}"
ARX  = "{http://arxiv.org/schemas/atom}"
mode = os.environ.get("MODE", "line")
exclude = os.environ.get("EXCLUDE", "")
raw = sys.stdin.read()
try:
    root = ET.fromstring(raw)
except Exception:
    sys.exit(3)
def collapse(s):
    return re.sub(r"\s+", " ", (s or "")).strip()
def strip_ver(s):
    return re.sub(r"v\d+$", "", s)
n = 0
for e in root.findall(f"{ATOM}entry"):
    raw_id = collapse(e.findtext(f"{ATOM}id"))
    aid = raw_id.rsplit("/abs/", 1)[-1] if "/abs/" in raw_id else raw_id
    if exclude and strip_ver(aid) == strip_ver(exclude):
        continue
    title = collapse(e.findtext(f"{ATOM}title"))
    pub = collapse(e.findtext(f"{ATOM}published"))[:10]
    cats = [c.get("term") for c in e.findall(f"{ATOM}category") if c.get("term")]
    prim = e.find(f"{ARX}primary_category")
    primt = prim.get("term") if prim is not None else (cats[0] if cats else "")
    if mode == "line":
        print(f"{aid} | {pub} | {primt} | {title}")
    else:
        authors = "; ".join(collapse(a.findtext(f"{ATOM}name")) for a in e.findall(f"{ATOM}author"))
        summary = collapse(e.findtext(f"{ATOM}summary"))
        print(f"id: {aid}")
        print(f"title: {title}")
        print(f"authors: {authors}")
        print(f"published: {pub}")
        print(f"categories: {', '.join(cats) if cats else primt}")
        print(f"abstract: {summary}")
        print(f"url: https://arxiv.org/abs/{aid}")
    n += 1
sys.exit(0 if n else 4)
PY

# Parse an arXiv Atom feed (stdin) into our line/full format. $1 = mode (line|full),
# $2 = arxiv_id to EXCLUDE (optional, used by `related`). A python3/python interpreter is
# preferred; a thin awk path covers the no-interpreter case (line mode only).
parse() {
  local mode="$1" exclude="${2:-}"
  if [ -n "${PY}" ]; then
    MODE="${mode}" EXCLUDE="${exclude}" "${PY}" -c "${PYPROG}"
    return $?
  fi
  # --- no python interpreter: best-effort line-mode extraction (id + title) ---
  [ "${mode}" = "line" ] || { echo "alphaxiv.sh: 'full' mode needs python3/python" >&2; return 3; }
  awk 'BEGIN{RS="<entry>"} NR>1{
        id=""; t="";
        if (match($0,/\/abs\/[^<]+/)) id=substr($0,RSTART+5,RLENGTH-5);
        if (match($0,/<title>[^<]*<\/title>/)) { t=substr($0,RSTART+7,RLENGTH-15); }
        gsub(/[ \t\n\r]+/," ",t); sub(/^ /,"",t); sub(/ $/,"",t);
        if (id!="") print id" | | | "t;
      }'
}

CMD="${1:-}"
case "${CMD}" in
  search)
    Q="${2:-}"; MAX="${3:-${DEFAULT_MAX}}"
    # Coerce a non-numeric/empty max to the default: under `set -u` a non-numeric
    # MAX makes the later $((MAX+1)) abort with "unbound variable" instead of
    # degrading cleanly. Never block the loop on a bad arg (see references/alphaxiv-bridge.md).
    case "${MAX}" in *[!0-9]*|"") MAX="${DEFAULT_MAX}" ;; esac
    [ -n "${Q}" ] || { echo "ALPHAXIV_AVAILABLE=none (empty query)"; usage; exit 2; }
    # If the caller gave no arXiv field prefix, search all fields.
    case "${Q}" in *:*) SQ="${Q}";; *) SQ="all:${Q}";; esac
    XML="$(arxiv_fetch --data-urlencode "search_query=${SQ}" \
                       --data "start=0" --data "max_results=${MAX}" \
                       --data "sortBy=${SORT}" --data "sortOrder=descending")" \
      || { echo "ALPHAXIV_AVAILABLE=none (network/arxiv unreachable; primary=alphaXiv MCP ${MCP_URL})"; exit 2; }
    printf '%s\n' "${XML}" | parse line
    ;;
  paper)
    ID="${2:-}"
    [ -n "${ID}" ] || { echo "ALPHAXIV_AVAILABLE=none (no arxiv id)"; usage; exit 2; }
    XML="$(arxiv_fetch --data-urlencode "id_list=${ID}" --data "max_results=1")" \
      || { echo "ALPHAXIV_AVAILABLE=none (network/arxiv unreachable)"; exit 2; }
    printf '%s\n' "${XML}" | parse full
    ;;
  related)
    ID="${2:-}"; MAX="${3:-${DEFAULT_MAX}}"
    case "${MAX}" in *[!0-9]*|"") MAX="${DEFAULT_MAX}" ;; esac   # see `search` above: keep $((MAX+1)) safe
    [ -n "${ID}" ] || { echo "ALPHAXIV_AVAILABLE=none (no arxiv id)"; usage; exit 2; }
    XML="$(arxiv_fetch --data-urlencode "id_list=${ID}" --data "max_results=1")" \
      || { echo "ALPHAXIV_AVAILABLE=none (network/arxiv unreachable)"; exit 2; }
    # Pull the seed's primary category + a few title keywords, then search neighbours.
    SEED="$(printf '%s\n' "${XML}" | parse line | head -n1)"
    [ -n "${SEED}" ] || { echo "ALPHAXIV_AVAILABLE=none (arxiv id not found: ${ID})"; exit 2; }
    CAT="$(printf '%s' "${SEED}" | awk -F' \\| ' '{print $3}')"
    TITLE="$(printf '%s' "${SEED}" | awk -F' \\| ' '{print $4}')"
    # keep the 4 longest title words as topic terms (drop short/stop-ish words)
    TERMS="$(printf '%s' "${TITLE}" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' ' ' \
             | tr ' ' '\n' | awk '{ if (length($0) >= 5) print }' \
             | sort -u | head -n4 | paste -sd' ' -)"
    [ -n "${TERMS}" ] || TERMS="${TITLE}"
    if [ -n "${CAT}" ]; then SQ="cat:${CAT} AND all:${TERMS}"; else SQ="all:${TERMS}"; fi
    XML2="$(arxiv_fetch --data-urlencode "search_query=${SQ}" \
                        --data "start=0" --data "max_results=$((MAX+1))" \
                        --data "sortBy=relevance" --data "sortOrder=descending")" \
      || { echo "ALPHAXIV_AVAILABLE=none (network/arxiv unreachable)"; exit 2; }
    printf '%s\n' "${XML2}" | parse line "${ID}" | head -n "${MAX}"
    ;;
  ""|-h|--help|help)
    usage
    [ -z "${CMD}" ] && exit 2 || exit 0
    ;;
  *)
    echo "ALPHAXIV_AVAILABLE=none (unknown subcommand: ${CMD})"; usage; exit 2
    ;;
esac
