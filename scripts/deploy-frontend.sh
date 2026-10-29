#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   pnpm run deploy:frontend
#   pnpm run deploy:frontend -- tradeflowbd

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Frontend builds must use production Supabase keys, not local Docker.
bash "${ROOT_DIR}/scripts/env-switch.sh" prod

if [[ -f web/.env ]]; then
  # shellcheck disable=SC1091
  set -a
  . web/.env
  set +a
fi

PROJECT_NAME="${1:-${CF_PAGES_PROJECT_NAME:-}}"
if [[ -z "${PROJECT_NAME}" ]]; then
  echo "Error: set CF_PAGES_PROJECT_NAME in web/.env.profile.prod (or web/.env) or pass project name as an argument."
  exit 1
fi

RETRY_ATTEMPTS="${CF_PAGES_DEPLOY_RETRIES:-5}"
RETRY_DELAY_BASE_SECONDS="${CF_PAGES_DEPLOY_RETRY_BASE_DELAY_SECONDS:-12}"
WRANGLER_VERSION="${CF_WRANGLER_VERSION:-}"
PAGES_SKIP_CACHING="${CF_PAGES_SKIP_CACHING:-false}"
CLEAN_DIST="${CF_PAGES_CLEAN_DIST:-false}"

wrangler_cmd() {
  if [[ -x "${ROOT_DIR}/node_modules/.bin/wrangler" ]]; then
    "${ROOT_DIR}/node_modules/.bin/wrangler" "$@"
  elif [[ -n "${WRANGLER_VERSION}" ]]; then
    npx -y "wrangler@${WRANGLER_VERSION}" "$@"
  else
    pnpm exec wrangler "$@"
  fi
}

# Heartbeat on stderr while a command runs (Wrangler upload is often silent for minutes).
run_wrangler_with_progress() {
  local label="$1"
  shift
  local start=$SECONDS

  (
    while true; do
      sleep 2
      printf '  … %s (%ds)\n' "${label}" $((SECONDS - start)) >&2
    done
  ) &
  local heartbeat_pid=$!

  set +e
  "$@"
  local exit_code=$?
  set -e

  kill "${heartbeat_pid}" 2>/dev/null || true
  wait "${heartbeat_pid}" 2>/dev/null || true
  printf '  ✓ Finished: %s (%ds)\n' "${label}" $((SECONDS - start)) >&2
  return "${exit_code}"
}

print_frontend_deploy_success() {
  local version="$1"
  local deploy_log="$2"
  local preview_url=""
  local live_url="${VITE_PRODUCTION_APP_URL:-}"

  if [[ -f "${deploy_log}" ]]; then
    preview_url="$(grep -Eo 'https://[a-f0-9]+\.[^[:space:]]+\.pages\.dev' "${deploy_log}" | tail -1 || true)"
    if [[ -z "${preview_url}" ]]; then
      preview_url="$(sed -n 's/.*Take a peek over at \(https\:\/\/[^[:space:]]*\).*/\1/p' "${deploy_log}" | tail -1 || true)"
    fi
  fi

  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Frontend deploy succeeded"
  echo "══════════════════════════════════════════════════════════════"
  echo "  Release version   ${version}"
  echo "  Cloudflare project ${PROJECT_NAME}"
  if [[ -n "${preview_url}" ]]; then
    echo "  Preview URL        ${preview_url}"
  fi
  if [[ -n "${live_url}" ]]; then
    echo "  Production URL     ${live_url}"
  fi
  if [[ -n "${VITE_SUPABASE_URL:-}" ]]; then
    echo "  Supabase (app)     ${VITE_SUPABASE_URL}"
  fi
  echo ""
  echo "  web/.env is on PRODUCTION. For local Docker again:"
  echo "    pnpm run env:local"
  echo "══════════════════════════════════════════════════════════════"
  echo ""
}

rm -rf web/.quasar web/dist

if ! pnpm install --frozen-lockfile; then
  echo "pnpm install --frozen-lockfile failed. Running pnpm install to resync dependencies..."
  pnpm install
fi

echo "Regenerating Quasar tsconfig (.quasar) after clean..."
pnpm --filter web exec quasar prepare

DEPLOY_VERSION="$(bash "${ROOT_DIR}/scripts/bump-app-release-version.sh")"
export VITE_APP_VERSION="${DEPLOY_VERSION}"
echo "Release version for this deploy: ${DEPLOY_VERSION}"

echo "Building production bundle..."
if ! pnpm --filter web build; then
  echo "ERROR: build failed. Deploy stopped. Fix the errors above and run again."
  exit 1
fi

# Optional: legacy guard if scraper/backup files ever land under dist (normal Quasar builds do not).
if [[ "${CLEAN_DIST}" == "true" ]]; then
  echo "CF_PAGES_CLEAN_DIST=true — removing uk/, *.bak*, .DS_Store from dist..."
  rm -rf web/dist/spa/uk
  rm -f web/dist/spa/*.bak*
  find web/dist/spa -name ".DS_Store" -type f -delete 2>/dev/null || true
fi

wrangler_cmd --version
echo ""

echo "Logging out of Cloudflare so you can pick the right account..."
run_wrangler_with_progress "Cloudflare logout" wrangler_cmd logout || true
echo "Opening Cloudflare login in your browser — complete it there if prompted."
run_wrangler_with_progress "Cloudflare login" wrangler_cmd login
echo ""

DIST_FILES="$(find web/dist/spa -type f 2>/dev/null | wc -l | tr -d ' ')"
DIST_MB="$(du -sm web/dist/spa 2>/dev/null | cut -f1)"
echo "Upload bundle: ${DIST_FILES} files, ~${DIST_MB} MB → project ${PROJECT_NAME}"
echo ""

WRANGLER_DEPLOY_LOG="$(mktemp)"
trap 'rm -f "${WRANGLER_DEPLOY_LOG}"' EXIT

WRANGLER_DEPLOY_SKIP_CACHING=()
if [[ "${PAGES_SKIP_CACHING}" == "true" ]]; then
  WRANGLER_DEPLOY_SKIP_CACHING=(--skip-caching)
  echo "CF_PAGES_SKIP_CACHING=true — uploading all assets (slower)."
fi

pages_deploy_cmd() {
  if ((${#WRANGLER_DEPLOY_SKIP_CACHING[@]} > 0)); then
    wrangler_cmd pages deploy web/dist/spa --project-name "${PROJECT_NAME}" --commit-dirty=true "${WRANGLER_DEPLOY_SKIP_CACHING[@]}" 2>&1 | tee "${WRANGLER_DEPLOY_LOG}"
  else
    wrangler_cmd pages deploy web/dist/spa --project-name "${PROJECT_NAME}" --commit-dirty=true 2>&1 | tee "${WRANGLER_DEPLOY_LOG}"
  fi
  return "${PIPESTATUS[0]}"
}

attempt=1
while [[ "${attempt}" -le "${RETRY_ATTEMPTS}" ]]; do
  echo "Uploading web/dist/spa to Cloudflare Pages (${PROJECT_NAME}), attempt ${attempt}/${RETRY_ATTEMPTS}..."
  if run_wrangler_with_progress "Pages upload" pages_deploy_cmd; then
    if ! bash "${ROOT_DIR}/scripts/record-app-release.sh" frontend "${DEPLOY_VERSION}"; then
      echo "Error: deploy succeeded but recording frontend release version failed (check SUPABASE_SECRET_KEY in web/.env.profile.prod)." >&2
      exit 1
    fi
    print_frontend_deploy_success "${DEPLOY_VERSION}" "${WRANGLER_DEPLOY_LOG}"
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
