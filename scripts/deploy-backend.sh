#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   pnpm run deploy:backend
#
# Requires SUPABASE_ACCESS_TOKEN (+ SUPABASE_PROJECT_REF) in web/.env.profile.prod.

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

echo "Pushing migrations to linked production..."
supabase_cmd db push --linked --include-all

echo "Regenerating types from linked production..."
mkdir -p web/src/types
supabase_cmd gen types typescript --linked --schema public > web/src/types/database.types.ts

echo "Backend deploy succeeded."
