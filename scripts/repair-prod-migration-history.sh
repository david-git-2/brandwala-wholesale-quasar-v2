#!/usr/bin/env bash
# Repair linked prod migration history so `supabase db push` matches top-level
# supabase/migrations/*.sql (baseline + post-cutover files). Legacy versions live
# under migrations/_legacy/ and are not visible to db push — mark them reverted
# on remote, then mark baseline applied (history only; do not re-run baseline SQL).
#
# Usage:
#   pnpm run backend:repair-prod-migrations          # repair only
#   pnpm run backend:repair-prod-migrations -- deploy # repair then deploy:backend
#
# Requires SUPABASE_ACCESS_TOKEN in web/.env.profile.prod (via env-switch prod).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RUN_DEPLOY=false
AUTO_YES=false
for arg in "$@"; do
  case "$arg" in
    deploy) RUN_DEPLOY=true ;;
    --yes|-y) AUTO_YES=true ;;
  esac
done

bash "${ROOT_DIR}/scripts/env-switch.sh" prod
# shellcheck source=scripts/load-supabase-deploy-env.sh
source "${ROOT_DIR}/scripts/load-supabase-deploy-env.sh"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Error: set SUPABASE_ACCESS_TOKEN in web/.env.profile.prod" >&2
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
fi

echo "Reading linked migration list..."
LIST_JSON="$(supabase_cmd migration list --linked --output-format json)"
export LIST_JSON

REVERT_VERSIONS="$(python3 <<'PY'
import json, os, glob

raw = os.environ.get("LIST_JSON", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError as e:
    raise SystemExit(f"Could not parse migration list JSON: {e}\n{raw[:500]}")

migrations = payload.get("migrations") or payload
if isinstance(migrations, dict) and "migrations" in migrations:
    migrations = migrations["migrations"]

local_versions = set()
for path in glob.glob("supabase/migrations/*.sql"):
    base = os.path.basename(path)
    if base.startswith("."):
        continue
    local_versions.add(base.split("_", 1)[0])

remote_versions = set()
for row in migrations:
    remote = (row.get("remote") or "").strip()
    if remote:
        remote_versions.add(remote)

orphan = sorted(v for v in remote_versions if v not in local_versions)
print("\n".join(orphan))
PY
)"

REVERT_COUNT="$(printf '%s\n' "$REVERT_VERSIONS" | sed '/^$/d' | wc -l | tr -d ' ')"
echo "Local top-level migration versions: $(ls supabase/migrations/*.sql 2>/dev/null | wc -l | tr -d ' ')"
echo "Remote orphan versions to mark reverted: ${REVERT_COUNT}"

if [[ "${REVERT_COUNT}" -eq 0 ]]; then
  echo "No orphan remote versions — history may already match local files."
else
  echo "Sample orphans (first 5):"
  printf '%s\n' "$REVERT_VERSIONS" | sed '/^$/d' | head -5
  echo "..."
  if [[ "${AUTO_YES}" != true ]]; then
    read -r -p "Mark ${REVERT_COUNT} remote versions as reverted? [y/N] " confirm
    if [[ "${confirm}" != [yY] ]]; then
      echo "Aborted."
      exit 1
    fi
  fi

  # Batch to avoid ARG_MAX
  batch=()
  n=0
  while IFS= read -r ver; do
    [[ -z "${ver}" ]] && continue
    batch+=("${ver}")
    n=$((n + 1))
    if [[ "${n}" -ge 80 ]]; then
      supabase_cmd migration repair --linked --status reverted "${batch[@]}" --yes
      batch=()
      n=0
    fi
  done <<< "$REVERT_VERSIONS"
  if [[ "${#batch[@]}" -gt 0 ]]; then
    supabase_cmd migration repair --linked --status reverted "${batch[@]}" --yes
  fi
  echo "Orphan versions marked reverted."
fi

echo "Ensuring baseline 00000000000000 is recorded as applied (history only)..."
supabase_cmd migration repair --linked --status applied 00000000000000 --yes

echo "Repair complete. Next: pnpm run backend:push  or  pnpm run deploy:backend"
echo "If db push fails with 'already exists', mark that migration applied:"
echo "  supabase migration repair --linked --status applied <version> --yes"

if [[ "${RUN_DEPLOY}" == true ]]; then
  bash "${ROOT_DIR}/scripts/deploy-backend.sh"
fi
