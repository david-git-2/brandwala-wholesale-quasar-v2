#!/usr/bin/env bash
# Switch Quasar web/.env between local Docker and production profiles.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_ACTIVE="${ROOT_DIR}/web/.env"
ENV_LOCAL="${ROOT_DIR}/web/.env.local"
ENV_PROD="${ROOT_DIR}/web/.env.prod"

print_target() {
  local url=""
  if [[ -f "$ENV_ACTIVE" ]]; then
    url="$(grep -E '^VITE_SUPABASE_URL=' "$ENV_ACTIVE" | head -1 | cut -d= -f2- || true)"
  fi
  echo "Active web/.env → VITE_SUPABASE_URL=${url:-<(missing)>}"
  echo "Restart the Quasar dev server (pnpm run dev) so Vite reloads env."
}

cmd_local() {
  if [[ ! -f "$ENV_LOCAL" ]]; then
    echo "Missing ${ENV_LOCAL}."
    echo "Create it once:"
    echo "  1. pnpm run backend:start"
    echo "  2. pnpm run backend:env:print > web/.env.local"
    echo "  3. Merge any Cloudinary / CF vars from web/.env.local.example or your prod env."
    exit 1
  fi
  cp "$ENV_LOCAL" "$ENV_ACTIVE"
  echo "Switched Quasar env to LOCAL (Docker)."
  print_target
}

cmd_prod() {
  if [[ ! -f "$ENV_PROD" ]]; then
    echo "Missing ${ENV_PROD}."
    echo "Create it once from your cloud keys, e.g.:"
    echo "  cp web/.env web/.env.prod   # when web/.env currently points at production"
    exit 1
  fi
  cp "$ENV_PROD" "$ENV_ACTIVE"
  echo "Switched Quasar env to PRODUCTION."
  print_target
}

cmd_status() {
  print_target
  [[ -f "$ENV_LOCAL" ]] && echo "Profile present: web/.env.local" || echo "Profile missing: web/.env.local"
  [[ -f "$ENV_PROD" ]] && echo "Profile present: web/.env.prod" || echo "Profile missing: web/.env.prod"
}

usage() {
  cat <<'EOF'
Usage: scripts/env-switch.sh <local|prod|status>

  local   Copy web/.env.local → web/.env
  prod    Copy web/.env.prod  → web/.env
  status  Show active URL and which profiles exist
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
