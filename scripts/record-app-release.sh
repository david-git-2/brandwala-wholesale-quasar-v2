#!/usr/bin/env bash
set -euo pipefail

# Usage: record-app-release.sh backend|frontend [version]
# Default version: semver from repo package.json (e.g. 1.0.0). Override with 2nd arg.
# Writes public.app_release_versions via PostgREST (service role).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIND="${1:-}"
VERSION="${2:-}"

if [[ "${KIND}" != "backend" && "${KIND}" != "frontend" ]]; then
  echo "Usage: $0 backend|frontend [version]" >&2
  exit 1
fi

if [[ -z "${VERSION}" ]]; then
  if command -v node >/dev/null 2>&1; then
    VERSION="$(node -p "require('${ROOT_DIR}/package.json').version")"
  else
    VERSION="1.0.0"
  fi
fi

if [[ -f "${ROOT_DIR}/web/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "${ROOT_DIR}/web/.env"
  set +a
fi

BASE_URL="${SUPABASE_URL:-${VITE_SUPABASE_URL:-}}"
API_KEY="${SUPABASE_SECRET_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-}}"

if [[ -z "${BASE_URL}" || -z "${API_KEY}" ]]; then
  echo "record-app-release: skip (missing SUPABASE_URL or service role key)." >&2
  exit 0
fi

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
if [[ "${KIND}" == "backend" ]]; then
  BODY="{\"backend_version\":\"${VERSION}\",\"backend_updated_at\":\"${NOW}\"}"
else
  BODY="{\"frontend_version\":\"${VERSION}\",\"frontend_updated_at\":\"${NOW}\"}"
fi

HTTP_CODE="$(
  curl -sS -o /tmp/record-app-release.out -w "%{http_code}" \
    -X PATCH "${BASE_URL%/}/rest/v1/app_release_versions?id=eq.1" \
    -H "apikey: ${API_KEY}" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "${BODY}"
)"

if [[ "${HTTP_CODE}" != 204 && "${HTTP_CODE}" != 200 ]]; then
  echo "record-app-release: PATCH failed HTTP ${HTTP_CODE}: $(cat /tmp/record-app-release.out)" >&2
  exit 0
fi

echo "record-app-release: ${KIND}=${VERSION}"
