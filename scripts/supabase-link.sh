#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck source=scripts/load-supabase-deploy-env.sh
source "${ROOT_DIR}/scripts/load-supabase-deploy-env.sh"

if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo "Error: set SUPABASE_PROJECT_REF in web/.env.profile.prod"
  exit 1
fi

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Error: set SUPABASE_ACCESS_TOKEN in web/.env.profile.prod"
  echo "Create a token: https://supabase.com/dashboard/account/tokens"
  exit 1
fi

export SUPABASE_ACCESS_TOKEN

if [[ -x "${ROOT_DIR}/node_modules/.bin/supabase" ]]; then
  "${ROOT_DIR}/node_modules/.bin/supabase" link --project-ref "${SUPABASE_PROJECT_REF}"
else
  pnpm exec supabase link --project-ref "${SUPABASE_PROJECT_REF}"
fi
