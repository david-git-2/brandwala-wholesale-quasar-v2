#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   npm run deploy:frontend
#   npm run deploy:frontend -- tradeflowbd

if [[ -f web/.env ]]; then
  # shellcheck disable=SC1091
  set -a
  . web/.env
  set +a
fi

PROJECT_NAME="${1:-${CF_PAGES_PROJECT_NAME:-}}"
if [[ -z "${PROJECT_NAME}" ]]; then
  echo "Error: set CF_PAGES_PROJECT_NAME in web/.env or pass project name as an argument."
  exit 1
fi

RETRY_ATTEMPTS="${CF_PAGES_DEPLOY_RETRIES:-5}"
RETRY_DELAY_BASE_SECONDS="${CF_PAGES_DEPLOY_RETRY_BASE_DELAY_SECONDS:-12}"
WRANGLER_VERSION="${CF_WRANGLER_VERSION:-latest}"

wrangler_cmd() {
  npx -y "wrangler@${WRANGLER_VERSION}" "$@"
}

rm -rf web/.quasar web/dist

if ! npm --prefix web ci --include=optional; then
  echo "npm ci failed (likely lockfile drift). Running npm install to resync dependencies..."
  npm --prefix web install --include=optional
fi

npm --prefix web run build

# Clean up large scraper data, backups, and temporary files not used by the frontend
echo "Cleaning up local development data, backups, and DS_Store from build output..."
rm -rf web/dist/spa/uk
rm -f web/dist/spa/*.bak*
find web/dist/spa -name ".DS_Store" -type f -delete

echo "Using wrangler@${WRANGLER_VERSION}"
wrangler_cmd --version

if ! wrangler_cmd whoami >/dev/null 2>&1; then
  wrangler_cmd login
fi

attempt=1
while [[ "${attempt}" -le "${RETRY_ATTEMPTS}" ]]; do
  echo "Deploy attempt ${attempt}/${RETRY_ATTEMPTS}..."
  if wrangler_cmd pages deploy web/dist/spa --project-name "${PROJECT_NAME}" --commit-dirty=true --skip-caching; then
    echo "Deploy succeeded."
    exit 0
  fi

  if [[ "${attempt}" -ge "${RETRY_ATTEMPTS}" ]]; then
    break
  fi

  delay_seconds=$((attempt * RETRY_DELAY_BASE_SECONDS))
  echo "Deploy failed. Retrying in ${delay_seconds}s..."
  sleep "${delay_seconds}"
  attempt=$((attempt + 1))
done

echo "Deploy failed after ${RETRY_ATTEMPTS} attempts."
exit 1
