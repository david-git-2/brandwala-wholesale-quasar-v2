#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
rg_column_ref() {
  rg -n "$@" 2>/dev/null \
    | rg -v 'resolve_parent_tenant_id|user_can_manage_parent_tenant|v_parent_tenant_id' \
    || true
}

check_paths() {
  local label="$1"
  shift
  local hits
  hits="$(rg_column_ref '\bparent_tenant_id\b' "$@")"
  if [[ -n "$hits" ]]; then
    echo "$hits" >&2
    echo "check-no-parent-tenant-id: found parent_tenant_id in $label" >&2
    fail=1
  fi
}

check_paths "supabase/schemas" supabase/schemas --glob '!public.sql.bak' --glob '!*.pre-so3'
check_paths "supabase/tests" supabase/tests --glob '!no_parent_tenant_id.sql'
check_paths "web/src" web/src --glob '!database.types.ts'

while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  if [[ "$base" < "20261119233100" ]]; then
    continue
  fi
  if [[ "$base" == 20261119233* ]]; then
    continue
  fi
  if rg_column_ref '\bparent_tenant_id\b' "$f" | grep -q .; then
    echo "check-no-parent-tenant-id: found in migration $f" >&2
    fail=1
  fi
done < <(find supabase/migrations -maxdepth 1 -name '*.sql' -print0 2>/dev/null)

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "check-no-parent-tenant-id: ok"