#!/usr/bin/env bash
set -euo pipefail
# Progress on stderr so IDE / pnpm log capture still shows lines (stdout can be fully buffered).
deploy_log() { printf '%s\n' "$*" >&2; }

# Usage:
#   pnpm run frontend:prod
#   pnpm run frontend:prod -- tradeflowbd

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

# Do not run `wrangler logout` + `wrangler login` every deploy: login blocks on OAuth and looks
# "stuck" in IDE terminals; use an existing session, or CLOUDFLARE_API_TOKEN / CF_API_TOKEN.
ensure_cloudflare_auth() {
  if [[ "${CF_FORCE_WRANGLER_LOGIN:-}" == "true" ]]; then
    echo "CF_FORCE_WRANGLER_LOGIN=true — running wrangler login (browser OAuth)..."
    wrangler_cmd login
    return 0
  fi

  # API-only + account id: Wrangler whoami often needs "Account read" or fails to list accounts; deploy still works with CLOUDFLARE_ACCOUNT_ID set.
  local has_token=0
  if [[ -n "${CLOUDFLARE_API_TOKEN:-}" || -n "${CF_API_TOKEN:-}" ]]; then
    has_token=1
  fi
  if [[ "${has_token}" -eq 1 && -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    deploy_log "Cloudflare: API token + CLOUDFLARE_ACCOUNT_ID set — skipping wrangler whoami (token may be Pages-only)."
    return 0
  fi

  # Do not redirect whoami to /dev/null — a slow or hanging API looks like a freeze after the version banner.
  local whoami_timeout="${CF_WRANGLER_WHOAMI_TIMEOUT_SECONDS:-90}"
  deploy_log "Checking Cloudflare session (wrangler whoami, ${whoami_timeout}s max) — can take a bit if the network is slow."
  set +e
  local whoami_tmp
  whoami_tmp="$(mktemp)"
  # Capture output so Wrangler’s stdout is not lost to pnpm/IDE pipe buffering while whoami runs in the background.
  ( wrangler_cmd whoami >"${whoami_tmp}" 2>&1 ) &
  local whoami_pid=$!
  local waited=0
  while kill -0 "${whoami_pid}" 2>/dev/null && [[ "${waited}" -lt "${whoami_timeout}" ]]; do
    sleep 1
    waited=$((waited + 1))
    if (( waited % 5 == 0 )); then
      deploy_log "  … still waiting for wrangler whoami (${waited}s / ${whoami_timeout}s)"
    fi
  done
  local whoami_code
  if kill -0 "${whoami_pid}" 2>/dev/null; then
    echo "Error: wrangler whoami did not finish within ${whoami_timeout}s (network, DNS, or Cloudflare API)." >&2
    kill "${whoami_pid}" 2>/dev/null || true
    wait "${whoami_pid}" 2>/dev/null || true
    whoami_code=124
  else
    wait "${whoami_pid}"
    whoami_code=$?
  fi
  if [[ -s "${whoami_tmp}" ]]; then
    cat "${whoami_tmp}" >&2
  fi
  rm -f "${whoami_tmp}"
  set -e
  if [[ "${whoami_code}" -eq 0 ]]; then
    deploy_log "Cloudflare: session OK."
    return 0
  fi

  if [[ "${whoami_code}" -eq 124 ]]; then
    echo "Tip: try again on a stable network, or set CLOUDFLARE_API_TOKEN and retry." >&2
    exit 1
  fi

  if [[ -n "${CLOUDFLARE_API_TOKEN:-}" || -n "${CF_API_TOKEN:-}" ]]; then
    echo "Error: an API token is set but wrangler whoami failed (exit ${whoami_code})." >&2
    echo "  Add CLOUDFLARE_ACCOUNT_ID to web/.env.profile.prod (Workers & Pages → overview → Account ID), or give the token Account → Account Settings → Read." >&2
    echo "  Or fix CLOUDFLARE_API_TOKEN / network/DNS." >&2
    exit 1
  fi

  if [[ -t 1 ]]; then
    echo "Cloudflare: not logged in. Running wrangler login — finish OAuth in the browser if it opens."
    wrangler_cmd login
    return 0
  fi

  echo "Error: Cloudflare CLI is not logged in and this is not an interactive terminal." >&2
  echo "  Run once in Terminal.app or iTerm: cd repo && wrangler login" >&2
  echo "  Or set CLOUDFLARE_API_TOKEN (or CF_API_TOKEN) in web/.env.profile.prod for CI / IDE deploys." >&2
  echo "  Or set CF_FORCE_WRANGLER_LOGIN=true to force browser login from a TTY." >&2
  exit 1
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
deploy_log ""
deploy_log "Next: Cloudflare auth check, then Pages upload (upload prints progress dots every 2s)."
deploy_log ""

ensure_cloudflare_auth
deploy_log ""

DIST_FILES="$(find web/dist/spa -type f 2>/dev/null | wc -l | tr -d ' ')"
DIST_MB="$(du -sm web/dist/spa 2>/dev/null | cut -f1)"
echo "Upload bundle: ${DIST_FILES} files, ~${DIST_MB} MB → project ${PROJECT_NAME}"
echo ""

# Wrangler pages deploy refuses session/OAuth in non-TTY environments (Cursor IDE, CI). API token required.
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" && -z "${CF_API_TOKEN:-}" ]] && ! [[ -t 1 ]]; then
  deploy_log "Error: this shell has no TTY. Wrangler needs CLOUDFLARE_API_TOKEN or CF_API_TOKEN for Pages deploy."
  deploy_log "  Put the token in web/.env.profile.prod (then pnpm run frontend:prod loads web/.env), or export it in your shell."
  deploy_log "  Create token: https://developers.cloudflare.com/fundamentals/api/get-started/create-token/"
  exit 1
fi

if [[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  export CLOUDFLARE_ACCOUNT_ID
fi

if [[ (-n "${CLOUDFLARE_API_TOKEN:-}" || -n "${CF_API_TOKEN:-}") && -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]] && ! [[ -t 1 ]]; then
  deploy_log "Tip: set CLOUDFLARE_ACCOUNT_ID in web/.env.profile.prod if deploy fails with \"retrieve account IDs\" (Workers & Pages → your account → Account ID on the right)."
fi

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

  if [[ -f "${WRANGLER_DEPLOY_LOG}" ]] && grep -q 'non-interactive' "${WRANGLER_DEPLOY_LOG}" 2>/dev/null && grep -q 'CLOUDFLARE_API_TOKEN' "${WRANGLER_DEPLOY_LOG}" 2>/dev/null; then
    deploy_log "Pages deploy cannot succeed without CLOUDFLARE_API_TOKEN in this environment — not retrying."
    exit 1
  fi

  if [[ -f "${WRANGLER_DEPLOY_LOG}" ]] && grep -q 'retrieve account IDs' "${WRANGLER_DEPLOY_LOG}" 2>/dev/null; then
    deploy_log "Wrangler could not resolve account — set CLOUDFLARE_ACCOUNT_ID in web/.env.profile.prod or add Account → Read to the API token. Not retrying."
    exit 1
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
