#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   pnpm run backend:clean
#
# Switches Quasar env to production, links the remote project, and deletes
# all rows from public.product_sync_snapshots (sync log; safe to empty).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash "${ROOT_DIR}/scripts/env-switch.sh" prod

# shellcheck source=scripts/load-supabase-deploy-env.sh
source "${ROOT_DIR}/scripts/load-supabase-deploy-env.sh"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Error: set SUPABASE_ACCESS_TOKEN in web/.env.profile.prod (copied to web/.env by env:prod)."
  echo "Create a token: https://supabase.com/dashboard/account/tokens"
  exit 1
fi

export SUPABASE_ACCESS_TOKEN

supabase_cmd() {
  if [[ -x "${ROOT_DIR}/node_modules/.bin/supabase" ]]; then
    "${ROOT_DIR}/node_modules/.bin/supabase" "$@"
  else
    pnpm exec supabase "$@"
  fi
}

if [[ -n "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo "Linking Supabase project ${SUPABASE_PROJECT_REF}..."
  supabase_cmd link --project-ref "${SUPABASE_PROJECT_REF}"
elif [[ ! -f "${ROOT_DIR}/supabase/.temp/project-ref" ]]; then
  echo "Error: set SUPABASE_PROJECT_REF in web/.env.profile.prod or run pnpm run backend:link once."
  exit 1
else
  echo "Using linked project: $(cat "${ROOT_DIR}/supabase/.temp/project-ref")"
fi

echo "Counting product_sync_snapshots rows on linked production..."
supabase_cmd db query --linked "SELECT count(*) AS snapshot_rows FROM public.product_sync_snapshots;"

echo "Deleting all product_sync_snapshots rows on linked production..."
supabase_cmd db query --linked "DELETE FROM public.product_sync_snapshots;"

echo "Remaining rows:"
supabase_cmd db query --linked "SELECT count(*) AS snapshot_rows FROM public.product_sync_snapshots;"

echo "backend:clean succeeded."
echo "To reclaim disk space, run VACUUM FULL public.product_sync_snapshots; in the Supabase SQL editor (CLI cannot VACUUM inside a transaction)."
