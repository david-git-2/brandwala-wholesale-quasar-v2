#!/usr/bin/env bash
# Load SUPABASE_ACCESS_TOKEN and SUPABASE_PROJECT_REF for linked remote CLI commands.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

dotenv_get() {
  local file="$1"
  local key="$2"
  local line val
  [[ -f "$file" ]] || return 1
  line="$(grep -E "^[[:space:]]*${key}=" "$file" | head -1 || true)"
  [[ -n "$line" ]] || return 1
  val="${line#*=}"
  val="${val%$'\r'}"
  if [[ "$val" == \"*\" ]]; then
    val="${val:1:${#val}-2}"
  elif [[ "$val" == \'*\' ]]; then
    val="${val:1:${#val}-2}"
  fi
  [[ -n "$val" ]] || return 1
  printf '%s' "$val"
}

is_placeholder() {
  case "$1" in
    ''|your_*|change_me*) return 0 ;;
    *) return 1 ;;
  esac
}

load_supabase_deploy_env() {
  if [[ -f "${ROOT_DIR}/.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    . "${ROOT_DIR}/.env"
    set +a
  fi

  local file token ref
  for file in \
    "${ROOT_DIR}/web/.env.profile.prod" \
    "${ROOT_DIR}/web/.env.prod" \
    "${ROOT_DIR}/web/.env" \
    "${ROOT_DIR}/.env"
  do
    if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
      if token="$(dotenv_get "$file" SUPABASE_ACCESS_TOKEN 2>/dev/null)" && ! is_placeholder "$token"; then
        export SUPABASE_ACCESS_TOKEN="$token"
      fi
    fi
    if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
      if ref="$(dotenv_get "$file" SUPABASE_PROJECT_REF 2>/dev/null)" && ! is_placeholder "$ref"; then
        export SUPABASE_PROJECT_REF="$ref"
      fi
    fi
  done
}

load_supabase_deploy_env
