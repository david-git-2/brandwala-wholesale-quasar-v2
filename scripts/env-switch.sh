#!/usr/bin/env bash
# Switch Quasar web/.env between local Docker and production profiles.
#
# Profiles MUST NOT be named web/.env.local — Quasar/Vite always auto-loads
# `.env.local` and it overrides `web/.env`, so env:prod would appear broken.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_ACTIVE="${ROOT_DIR}/web/.env"
ENV_LOCAL="${ROOT_DIR}/web/.env.profile.local"
ENV_PROD="${ROOT_DIR}/web/.env.profile.prod"
# Legacy names (pre-fix)
ENV_LOCAL_LEGACY="${ROOT_DIR}/web/.env.local"
ENV_PROD_LEGACY="${ROOT_DIR}/web/.env.prod"

migrate_legacy_profiles() {
  if [[ ! -f "$ENV_LOCAL" && -f "$ENV_LOCAL_LEGACY" ]]; then
    mv "$ENV_LOCAL_LEGACY" "$ENV_LOCAL"
    echo "Migrated web/.env.local → web/.env.profile.local (avoids Vite override)."
  fi
  if [[ ! -f "$ENV_PROD" && -f "$ENV_PROD_LEGACY" ]]; then
    mv "$ENV_PROD_LEGACY" "$ENV_PROD"
    echo "Migrated web/.env.prod → web/.env.profile.prod."
  fi
  # Leftover .env.local always wins over .env in Vite — remove if still present.
  if [[ -f "$ENV_LOCAL_LEGACY" ]]; then
    rm -f "$ENV_LOCAL_LEGACY"
    echo "Removed leftover web/.env.local so active web/.env is used."
  fi
}

print_target() {
  local url=""
  if [[ -f "$ENV_ACTIVE" ]]; then
    url="$(grep -E '^VITE_SUPABASE_URL=' "$ENV_ACTIVE" | head -1 | cut -d= -f2- || true)"
  fi
  echo "Active web/.env → VITE_SUPABASE_URL=${url:-<(missing)>}"
  if [[ -f "$ENV_LOCAL_LEGACY" ]]; then
    echo "WARNING: web/.env.local still exists and will override the URL above. Run this script again or delete it."
  fi
  echo "Restart the Quasar dev server (pnpm run dev) so Vite reloads env."
}

cmd_local() {
  migrate_legacy_profiles
  if [[ ! -f "$ENV_LOCAL" ]]; then
    echo "Missing ${ENV_LOCAL}."
    echo "Create it once:"
    echo "  1. pnpm run backend:start"
    echo "  2. pnpm run backend:env:print > web/.env.profile.local"
    echo "  3. Merge any Cloudinary / CF vars from web/.env.local.example or your prod profile."
    exit 1
  fi
  cp "$ENV_LOCAL" "$ENV_ACTIVE"
  echo "Switched Quasar env to LOCAL (Docker)."
  print_target
}

cmd_prod() {
  migrate_legacy_profiles
  if [[ ! -f "$ENV_PROD" ]]; then
    echo "Missing ${ENV_PROD}."
    echo "Create it once from your cloud keys, e.g.:"
    echo "  cp web/.env web/.env.profile.prod   # when web/.env currently points at production"
    exit 1
  fi
  cp "$ENV_PROD" "$ENV_ACTIVE"
  echo "Switched Quasar env to PRODUCTION."
  print_target
}

cmd_status() {
  migrate_legacy_profiles
  print_target
  [[ -f "$ENV_LOCAL" ]] && echo "Profile present: web/.env.profile.local" || echo "Profile missing: web/.env.profile.local"
  [[ -f "$ENV_PROD" ]] && echo "Profile present: web/.env.profile.prod" || echo "Profile missing: web/.env.profile.prod"
}

usage() {
  cat <<'EOF'
Usage: scripts/env-switch.sh <local|prod|status>

  local   Copy web/.env.profile.local → web/.env
  prod    Copy web/.env.profile.prod  → web/.env
  status  Show active URL and which profiles exist

Note: Do not store the local profile as web/.env.local — Vite auto-loads that
file and it overrides web/.env.
EOF
}

main() {
  case "${1:-}" in
    local) cmd_local ;;
    prod) cmd_prod ;;
    status) cmd_status ;;
    -h|--help|help|"") usage ;;
    *)
      echo "Unknown command: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
