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

rm -rf web/node_modules web/.quasar web/dist

if ! npm --prefix web ci --include=optional; then
  echo "npm ci failed (likely lockfile drift). Running npm install to resync dependencies..."
  npm --prefix web install --include=optional
fi

npm --prefix web exec -- wrangler login
npm --prefix web run build
npm --prefix web exec -- wrangler pages deploy web/dist/spa --project-name "${PROJECT_NAME}" --commit-dirty=true
