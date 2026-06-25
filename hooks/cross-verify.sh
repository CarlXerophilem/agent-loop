#!/usr/bin/env bash
# cross-verify.sh — auto-dev cross-model verifier bridge (deep-reasoning loop §6.2).
#
# Sends a verification PROMPT to an INDEPENDENT model (no-anchoring: the verifier
# is told it did not write the work) and prints its critique on stdout. Provider
# is chosen by $AUTO_DEV_CROSS_MODEL plus the matching API key. If none is
# available it prints "CROSS_MODEL_AVAILABLE=none ..." and exits 2, so the caller
# falls back to the same-family devil's-advocate panel. NEVER blocks the loop.
#
# Usage:  cross-verify.sh "verification prompt"     (or pipe the prompt on stdin)
# Extends the operator's shared/cross_model_verification.md with a DeepSeek case.
set -u

PROMPT="${1:-}"
[ -z "${PROMPT}" ] && PROMPT="$(cat 2>/dev/null || true)"
[ -z "${PROMPT}" ] && { echo "CROSS_MODEL_AVAILABLE=none (empty prompt)"; exit 2; }
MODEL="${AUTO_DEV_CROSS_MODEL:-}"
# Resolve a Python 3 interpreter under any common name (python3 on *nix; python/py on
# Windows). Without this, a box that ships `python` but not `python3` silently degrades
# extract() to raw JSON. node / cat remain the last-resort fallbacks.
# Convention (shared with hooks/alphaxiv.sh): resolve once into PY, then GUARD every use
# with `[ -n "${PY}" ]` and branch to a non-Python fallback -- never `${PY:-python3}`,
# which would re-run a `python3` that `command -v` already ruled out.
PY="$(command -v python3 || command -v python || command -v py || true)"

json_escape() { # JSON-encode stdin as a string literal
  { [ -n "${PY}" ] && "${PY}" -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null; } \
    || node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.stringify(s)))'
}
extract() { # pull message text from a provider JSON response on stdin
  { [ -n "${PY}" ] && "${PY}" -c "import json,sys
d=json.load(sys.stdin)
print($1)" 2>/dev/null; } || cat
}
P="$(printf '%s' "${PROMPT}" | json_escape)"
SYS="You are an independent verification assistant. You did NOT write the work under review. Find the most serious weaknesses; if rigorous, say so explicitly."

case "${MODEL}" in
  deepseek*)
    [ -n "${DEEPSEEK_API_KEY:-}" ] || { echo "CROSS_MODEL_AVAILABLE=none (no DEEPSEEK_API_KEY)"; exit 2; }
    curl -s https://api.deepseek.com/chat/completions \
      -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" -H "Content-Type: application/json" \
      -d "{\"model\":\"${MODEL}\",\"temperature\":0.1,\"max_tokens\":2000,\"messages\":[{\"role\":\"system\",\"content\":$(printf '%s' "${SYS}" | json_escape)},{\"role\":\"user\",\"content\":${P}}]}" \
      | extract 'd["choices"][0]["message"]["content"]'
    ;;
  gpt-5*|gpt*)
    [ -n "${OPENAI_API_KEY:-}" ] || { echo "CROSS_MODEL_AVAILABLE=none (no OPENAI_API_KEY)"; exit 2; }
    curl -s https://api.openai.com/v1/chat/completions \
      -H "Authorization: Bearer ${OPENAI_API_KEY}" -H "Content-Type: application/json" \
      -d "{\"model\":\"${MODEL}\",\"temperature\":0.1,\"max_tokens\":2000,\"messages\":[{\"role\":\"system\",\"content\":$(printf '%s' "${SYS}" | json_escape)},{\"role\":\"user\",\"content\":${P}}]}" \
      | extract 'd["choices"][0]["message"]["content"]'
    ;;
  gemini*)
    [ -n "${GOOGLE_AI_API_KEY:-}" ] || { echo "CROSS_MODEL_AVAILABLE=none (no GOOGLE_AI_API_KEY)"; exit 2; }
    curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GOOGLE_AI_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"contents\":[{\"parts\":[{\"text\":${P}}]}],\"generationConfig\":{\"temperature\":0.1,\"maxOutputTokens\":2000}}" \
      | extract 'd["candidates"][0]["content"]["parts"][0]["text"]'
    ;;
  *)
    echo "CROSS_MODEL_AVAILABLE=none (set AUTO_DEV_CROSS_MODEL to deepseek-*, gpt-*, or gemini-*)"
    exit 2
    ;;
esac
