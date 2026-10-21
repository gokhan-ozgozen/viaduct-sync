#!/usr/bin/env bash
# Reports whether this job can obtain a GitHub OIDC token and, through it, the dependency mirror.
set -uo pipefail

label="$1"
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] || [ -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]; then
  token_result="no OIDC request URL/token exposed to the job"
else
  response="$(curl -sS -w '\n%{http_code}' \
    -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=sts.amazonaws.com")"
  code="${response##*$'\n'}"
  jwt="$(printf '%s' "${response%$'\n'*}" | sed -n 's/.*"value":"\([^"]*\)".*/\1/p')"
  if [ -n "$jwt" ]; then
    echo "::add-mask::${jwt}"
    payload="$(printf '%s' "$jwt" | cut -d. -f2 | tr '_-' '/+')"
    while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="${payload}="; done
    sub="$(printf '%s' "$payload" | base64 -d 2>/dev/null | sed -n 's/.*"sub":"\([^"]*\)".*/\1/p')"
    token_result="token issued (HTTP ${code}), sub=${sub}"
  else
    token_result="token request refused (HTTP ${code})"
  fi
fi

unset VIADUCT_ARTIFACTORY_MIRROR
env_file="$(mktemp)"
GITHUB_ENV="$env_file" bash .github/scripts/configure-dependency-mirror.sh >/dev/null
if grep -q '^VIADUCT_ARTIFACTORY_MIRROR=' "$env_file"; then
  mirror_result="mirror configured"
else
  mirror_result="mirror NOT configured"
fi

{
  echo "### id-token: ${label}"
  echo "- OIDC: ${token_result}"
  echo "- CodeArtifact: ${mirror_result}"
} >> "$summary"
echo "id-token: ${label} -> OIDC: ${token_result}; CodeArtifact: ${mirror_result}"
