#!/usr/bin/env bash
# Talks to the memos REST API for this demo.
#
#   memos-api.sh signup         create the demo account (the first account is the admin)
#   memos-api.sh post <text>    create a private memo
#   memos-api.sh find <text>    succeed when a memo contains <text>
#
# MEMOS_URL defaults to http://localhost:5230. MEMOS_PASSWORD must be set.
set -euo pipefail

url="${MEMOS_URL:-http://localhost:5230}"
user="demo"
password="${MEMOS_PASSWORD:?set MEMOS_PASSWORD}"

token() {
  curl -sf -X POST "${url}/api/auth/signin" -H 'Content-Type: application/json' \
    -d "$(jq -n --arg u "$user" --arg p "$password" '{passwordCredentials: {username: $u, password: $p}}')" |
    jq -r .accessToken
}

case "${1:-}" in
  signup)
    curl -sf -X POST "${url}/api/users" -H 'Content-Type: application/json' \
      -d "$(jq -n --arg u "$user" --arg p "$password" '{username: $u, password: $p, role: "ADMIN"}')" |
      jq -r '"created account " + .username'
    ;;
  post)
    curl -sf -X POST "${url}/api/memos" -H "Authorization: Bearer $(token)" -H 'Content-Type: application/json' \
      -d "$(jq -n --arg c "${2:?text}" '{content: $c, visibility: "PRIVATE"}')" |
      jq -r '"created " + .name + ": " + .content'
    ;;
  find)
    curl -sf "${url}/api/memos?pageSize=1000" -H "Authorization: Bearer $(token)" |
      jq -e --arg t "${2:?text}" '[.memos[].content | select(contains($t))] | if length > 0 then .[0] else error("no memo contains the text") end'
    ;;
  *)
    sed -n '2,8p' "$0" >&2
    exit 1
    ;;
esac
