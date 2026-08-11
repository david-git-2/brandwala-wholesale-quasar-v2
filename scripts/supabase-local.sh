#!/usr/bin/env bash
# Local Supabase (Docker) helpers. Never runs db push --linked.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DUMP_DIR="${ROOT_DIR}/supabase/.dumps"
ROLES_FILE="${DUMP_DIR}/roles.sql"
SCHEMA_FILE="${DUMP_DIR}/schema.sql"
DATA_FILE="${DUMP_DIR}/data.sql"
DATA_PUBLIC_FILE="${DUMP_DIR}/data_public.sql"
DATA_AUTH_FILE="${DUMP_DIR}/data_auth.sql"
DATA_COMPAT_FILE="${DUMP_DIR}/data.compat.sql"
COLUMNS_MAP_FILE="${DUMP_DIR}/local_columns.map"

supabase_cli() {
  if [[ -x "${ROOT_DIR}/node_modules/.bin/supabase" ]]; then
    "${ROOT_DIR}/node_modules/.bin/supabase" "$@"
  else
    pnpm exec supabase "$@"
  fi
}

require_dump_dir() {
  mkdir -p "$DUMP_DIR"
  # Resolve and enforce writes stay under supabase/.dumps
  local resolved
  resolved="$(cd "$DUMP_DIR" && pwd -P)"
  case "$resolved" in
    "${ROOT_DIR}/supabase/.dumps"|"${ROOT_DIR}/supabase/.dumps"/*) ;;
    *)
      echo "Error: dump path escaped supabase/.dumps: $resolved" >&2
      exit 1
      ;;
  esac
}

require_local_running() {
  if ! supabase_cli status >/dev/null 2>&1; then
    echo "Error: local Supabase is not running. Start with: pnpm run backend:start" >&2
    exit 1
  fi
}

require_linked() {
  if [[ -f "${ROOT_DIR}/supabase/.temp/project-ref" ]]; then
    return 0
  fi
  echo "Error: no linked project (missing supabase/.temp/project-ref)." >&2
  echo "Run: pnpm run backend:login && SUPABASE_PROJECT_REF=... pnpm run backend:link" >&2
  exit 1
}

load_root_env() {
  if [[ -f "${ROOT_DIR}/.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    # shellcheck source=/dev/null
    . "${ROOT_DIR}/.env"
    set +a
  fi
}

# Read a KEY=value from a dotenv file (first match). Strips simple quotes.
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

# Local GoTrue needs the same Google OAuth client as prod.
# Fill missing GOOGLE_* from: root .env → profile prod → legacy .env.prod → web/.env
load_google_oauth_env() {
  load_root_env

  local file id secret
  for file in \
    "${ROOT_DIR}/.env" \
    "${ROOT_DIR}/web/.env.profile.prod" \
    "${ROOT_DIR}/web/.env.prod" \
    "${ROOT_DIR}/web/.env"
  do
    if [[ -z "${GOOGLE_CLIENT_ID:-}" ]]; then
      if id="$(dotenv_get "$file" GOOGLE_CLIENT_ID 2>/dev/null)"; then
        case "$id" in
          ''|your_google*|change_me*) ;;
          *) export GOOGLE_CLIENT_ID="$id" ;;
        esac
      fi
    fi
    if [[ -z "${GOOGLE_CLIENT_SECRET:-}" ]]; then
      if secret="$(dotenv_get "$file" GOOGLE_CLIENT_SECRET 2>/dev/null)"; then
        case "$secret" in
          ''|your_google*|change_me*) ;;
          *) export GOOGLE_CLIENT_SECRET="$secret" ;;
        esac
      fi
    fi
  done

  if [[ -z "${GOOGLE_CLIENT_ID:-}" || -z "${GOOGLE_CLIENT_SECRET:-}" ]]; then
    echo "Warning: GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET not found."
    echo "         Add the same values as Supabase Dashboard → Authentication → Google"
    echo "         into web/.env.profile.prod (preferred) or web/.env, then re-run start."
    echo "         Also add redirect URI: http://127.0.0.1:54321/auth/v1/callback"
  else
    echo "Google OAuth client loaded for local Auth (from env profiles)."
  fi
}

local_stack_healthy() {
  supabase_cli status >/dev/null 2>&1
}

cmd_start() {
  load_google_oauth_env

  if local_stack_healthy; then
    echo "Local Supabase is already running."
    supabase_cli status
    echo
    echo "Next: pnpm run backend:env:print  # seed web/.env.profile.local if needed"
    echo "Then: pnpm run env:local && pnpm run dev"
    return 0
  fi

  set +e
  supabase_cli start
  local start_rc=$?
  set -e

  if [[ "$start_rc" -eq 0 ]] || local_stack_healthy; then
    echo
    echo "Local stack is up. Next: pnpm run backend:env:print → web/.env.profile.local; pnpm run env:local"
    return 0
  fi

  # Race: CLI reports "already running" / DB still booting.
  echo "Start reported an error; waiting for DB to become healthy…"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 3
    if local_stack_healthy; then
      echo "Stack is healthy now."
      supabase_cli status
      echo
      echo "Local stack is up. Next: pnpm run backend:env:print → web/.env.profile.local; pnpm run env:local"
      return 0
    fi
  done

  echo "Retrying with a soft restart (keeps local data volumes)…"
  supabase_cli stop || true
  supabase_cli start
  echo
  echo "Local stack is up. Next: pnpm run backend:env:print → web/.env.profile.local; pnpm run env:local"
}

cmd_stop() {
  supabase_cli stop
}

cmd_status() {
  supabase_cli status
}

cmd_reset() {
  load_root_env
  echo "Rebuilding local DB from migrations only (no prod data dump)."
  echo "Use this to iterate migration fixes quickly. When green: pnpm run backend:pull-prod-data"
  supabase_cli db reset --local
}

cmd_migrate() {
  require_local_running
  echo "Applying pending migrations to local DB (include-all for out-of-order files)…"
  supabase_cli migration up --local --include-all
}

cmd_env_print() {
  require_local_running
  # shellcheck disable=SC1090
  eval "$(supabase_cli status -o env)"

  local api_url="${API_URL:-${SUPABASE_URL:-}}"
  local anon="${ANON_KEY:-${SUPABASE_ANON_KEY:-${PUBLISHABLE_KEY:-}}}"
  local service="${SERVICE_ROLE_KEY:-${SUPABASE_SERVICE_ROLE_KEY:-${SECRET_KEY:-}}}"

  if [[ -z "$api_url" || -z "$anon" ]]; then
    echo "Could not parse status env. Raw output:" >&2
    supabase_cli status -o env >&2
    exit 1
  fi

  cat <<EOF
# Paste into web/.env for local Docker development
VITE_SUPABASE_URL=${api_url}
VITE_SUPABASE_ANON_KEY=${anon}
VITE_LOCAL_APP_URL=http://127.0.0.1:9000

# Python / scripts (local service role — never ship to the browser)
SUPABASE_SECRET_KEY=${service}
EOF
}

cmd_types_local() {
  require_local_running
  mkdir -p web/src/types
  supabase_cli gen types typescript --local --schema public > web/src/types/database.types.ts
  echo "Wrote web/src/types/database.types.ts from local DB."
}

confirm_pull() {
  local force="${1:-}"
  if [[ "$force" == "--force" ]]; then
    return 0
  fi
  cat <<'EOF'
WARNING: backend:pull-prod-data will:
  • Dump the LINKED remote (production) database into supabase/.dumps/ (gitignored)
  • Reset local Docker DB from migrations, then restore DATA into local only
  • OVERWRITE all local database contents
  • NOT copy Storage file blobs (Cloudinary URLs still work against the cloud)
  • NEVER push or write schema changes to production

Type "yes" to continue:
EOF
  local answer
  read -r answer
  if [[ "$answer" != "yes" ]]; then
    echo "Aborted."
    exit 1
  fi
}

# Prefer host psql; fall back to psql inside the local Supabase DB container.
run_local_psql() {
  local db_url="${1:-}"
  shift

  if command -v psql >/dev/null 2>&1; then
    psql --dbname "$db_url" "$@"
    return
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: psql not found and docker is unavailable." >&2
    echo "Install Postgres client: brew install libpq && brew link --force libpq" >&2
    exit 1
  fi

  local container
  container="$(docker ps --format '{{.Names}}' | grep -E '^supabase_db_' | head -1 || true)"
  if [[ -z "$container" ]]; then
    echo "Error: psql not found and no running supabase_db_* container." >&2
    echo "Install Postgres client: brew install libpq && brew link --force libpq" >&2
    exit 1
  fi

  echo "Using psql inside Docker container: ${container}"
  # Map host-style flags to in-container defaults (user/db from local supabase).
  docker exec -i "$container" psql -U postgres -d postgres "$@"
}

restore_sql_file() {
  local db_url="$1"
  local file="$2"
  if [[ ! -f "$file" ]]; then
    echo "Warning: missing $file — skip" >&2
    return 0
  fi
  echo "  restoring $(basename "$file")…"
  if command -v psql >/dev/null 2>&1; then
    run_local_psql "$db_url" \
      --single-transaction \
      --variable ON_ERROR_STOP=1 \
      --command 'SET session_replication_role = replica' \
      --file "$file"
  else
    run_local_psql "$db_url" \
      --single-transaction \
      --variable ON_ERROR_STOP=1 \
      --command 'SET session_replication_role = replica' \
      -f - <"$file"
  fi
}

export_local_columns_map() {
  local db_url="$1"
  local out_file="$2"
  echo "→ Exporting local column map…"
  local sql
  sql=$(cat <<'SQL'
COPY (
  SELECT
    table_schema || '.' || table_name,
    string_agg(column_name, ',' ORDER BY ordinal_position)
  FROM information_schema.columns
  WHERE table_schema IN ('public', 'auth')
  GROUP BY table_schema, table_name
  ORDER BY 1
) TO STDOUT
SQL
)
  if command -v psql >/dev/null 2>&1; then
    run_local_psql "$db_url" --command "$sql" >"$out_file"
  else
    printf '%s\n' "$sql" | run_local_psql "$db_url" -f - >"$out_file"
  fi
}

rewrite_dump_for_local() {
  local infile="$1"
  local outfile="$2"
  echo "→ Rewriting $(basename "$infile") to local columns…"
  python3 "${ROOT_DIR}/scripts/compat_rewrite_pg_dump.py" \
    "$COLUMNS_MAP_FILE" "$infile" "$outfile"
}

# Clear migration-seeded rows so prod COPY does not hit unique conflicts.
truncate_local_data() {
  local db_url="$1"
  echo "→ Truncating public (+ auth user) tables before data restore…"
  local sql
  sql=$(cat <<'SQL'
SET session_replication_role = replica;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT format('%I.%I', schemaname, tablename) AS fq
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE 'TRUNCATE TABLE ' || r.fq || ' CASCADE';
  END LOOP;
END $$;

-- Auth rows that dump will replace (keep GoTrue config / migrations).
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'audit_log_entries',
    'refresh_tokens',
    'sessions',
    'mfa_amr_claims',
    'mfa_challenges',
    'mfa_factors',
    'identities',
    'users',
    'flow_state',
    'one_time_tokens',
    'oauth_authorizations',
    'oauth_client_states',
    'oauth_consents',
    'oauth_clients',
    'saml_providers',
    'saml_relay_states',
    'sso_domains',
    'sso_providers',
    'webauthn_challenges',
    'webauthn_credentials'
  ]
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_tables WHERE schemaname = 'auth' AND tablename = t
    ) THEN
      EXECUTE format('TRUNCATE TABLE auth.%I CASCADE', t);
    END IF;
  END LOOP;
END $$;
SQL
)
  if command -v psql >/dev/null 2>&1; then
    run_local_psql "$db_url" --variable ON_ERROR_STOP=1 --command "$sql"
  else
    printf '%s\n' "$sql" | run_local_psql "$db_url" --variable ON_ERROR_STOP=1 -f -
  fi
}

# Strip pg dump artefacts / Auth tables that drift between hosted and local GoTrue.
sanitize_dump_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # Remove \restrict / \unrestrict lines from pg_dump 17 that can confuse restore tooling.
  if grep -qE '^\\restrict |^\\unrestrict ' "$file" 2>/dev/null; then
    sed -i.bak -E '/^\\restrict /d; /^\\unrestrict /d' "$file"
    rm -f "${file}.bak"
  fi
  # Drop COPY blocks for tables whose columns differ on local GoTrue (line-based; no catastrophic regex).
  if grep -qE 'COPY "?auth"?\."?custom_oauth_providers"?' "$file" 2>/dev/null; then
    python3 - "$file" <<'PY'
import sys
path = sys.argv[1]
out = []
skip = False
stripped = False
with open(path, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        if not skip and "custom_oauth_providers" in line and line.startswith("-- Data for Name:"):
            skip = True
            continue
        if not skip and line.startswith("COPY ") and "custom_oauth_providers" in line:
            skip = True
            continue
        if skip:
            if line == "\\.\n" or line == "\\.\r\n":
                skip = False
                stripped = True
                out.append("-- skipped auth.custom_oauth_providers (local GoTrue schema drift)\n")
            continue
        out.append(line)
if stripped:
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out)
    print(f"stripped auth.custom_oauth_providers from {path}", file=sys.stderr)
else:
    print(f"warning: custom_oauth_providers present but strip failed: {path}", file=sys.stderr)
PY
  fi
}

cmd_pull_prod_data() {
  local force=""
  local reuse=false
  local arg
  for arg in "$@"; do
    case "$arg" in
      --) ;;
      --force) force="--force" ;;
      --reuse-dumps) reuse=true; force="--force" ;;
    esac
  done

  load_google_oauth_env
  require_local_running
  if [[ "$reuse" != true ]]; then
    require_linked
  fi
  require_dump_dir
  confirm_pull "$force"

  if [[ "$reuse" == true ]] && [[ -f "$DATA_PUBLIC_FILE" || -f "$DATA_FILE" ]]; then
    echo "→ Reusing dumps in ${DUMP_DIR} (--reuse-dumps)"
  else
    echo "→ Dumping linked remote (roles / schema / public+auth data)…"
    supabase_cli db dump --linked -f "$ROLES_FILE" --role-only
    supabase_cli db dump --linked -f "$SCHEMA_FILE"

    # Public business data (matches local migration schema)
    supabase_cli db dump --linked -f "$DATA_PUBLIC_FILE" \
      --data-only \
      --use-copy \
      --schema public

    # Auth users/identities for Google login — exclude GoTrue tables that drift vs local image
    supabase_cli db dump --linked -f "$DATA_AUTH_FILE" \
      --data-only \
      --use-copy \
      --schema auth \
      -x "auth.custom_oauth_providers" \
      -x "auth.schema_migrations"

    # Soften known grant that breaks restores (keep dump for inspection).
    if grep -q 'GRANT "postgres" TO "cli_login_postgres"' "$ROLES_FILE" 2>/dev/null; then
      sed -i.bak 's/^GRANT "postgres" TO "cli_login_postgres"/-- GRANT "postgres" TO "cli_login_postgres"/' "$ROLES_FILE"
      rm -f "${ROLES_FILE}.bak"
    fi
  fi

  sanitize_dump_file "$DATA_PUBLIC_FILE"
  sanitize_dump_file "$DATA_AUTH_FILE"
  sanitize_dump_file "$DATA_FILE"

  echo "→ Resetting local DB from migrations (clean schema)…"
  supabase_cli db reset --local --yes

  # shellcheck disable=SC1090
  eval "$(supabase_cli status -o env)"
  local db_url="${DB_URL:-}"
  if [[ -z "$db_url" ]]; then
    echo "Error: could not read DB_URL from supabase status -o env" >&2
    exit 1
  fi

  echo "→ Restoring data into local…"
  truncate_local_data "$db_url"
  export_local_columns_map "$db_url" "$COLUMNS_MAP_FILE"

  if [[ -f "$DATA_PUBLIC_FILE" ]]; then
    rewrite_dump_for_local "$DATA_PUBLIC_FILE" "${DUMP_DIR}/data_public.compat.sql"
    rewrite_dump_for_local "$DATA_AUTH_FILE" "${DUMP_DIR}/data_auth.compat.sql"
    restore_sql_file "$db_url" "${DUMP_DIR}/data_public.compat.sql"
    restore_sql_file "$db_url" "${DUMP_DIR}/data_auth.compat.sql"
  elif [[ -f "$DATA_FILE" ]]; then
    echo "  (legacy data.sql — prefer re-dump without --reuse-dumps if this fails)"
    rewrite_dump_for_local "$DATA_FILE" "$DATA_COMPAT_FILE"
    restore_sql_file "$db_url" "$DATA_COMPAT_FILE"
  else
    echo "Error: no data dump found in ${DUMP_DIR}" >&2
    exit 1
  fi

  cat <<EOF

Done. Local DB now has production data rows (best-effort).
  Dumps: ${DUMP_DIR}
  • Auth: users/identities restored; custom_oauth_providers skipped (local GoTrue drift)
  • Do not commit supabase/.dumps/
  • Storage blobs were not cloned
  • Point web/.env at local keys (pnpm run backend:env:print) and restart Quasar
  • Production was not modified
EOF
}

usage() {
  cat <<'EOF'
Usage: scripts/supabase-local.sh <command> [--force]

Commands:
  start            Start local Supabase (Docker)
  stop             Stop local Supabase
  status           Show local status / URLs / keys
  reset            db reset — migrations only, empty business data
  migrate          Apply pending migrations to local (migration up --include-all)
  env:print        Print VITE_* / service key snippet for web/.env
  pull-prod-data [--force] [--reuse-dumps]
                   Dump linked prod → restore public+auth data into local.
                   Skips auth.custom_oauth_providers (GoTrue drift).
                   --reuse-dumps skips remote dump (uses supabase/.dumps/)
  types:local      Generate database.types.ts from local DB
EOF
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    start) cmd_start "$@" ;;
    stop) cmd_stop "$@" ;;
    status) cmd_status "$@" ;;
    reset) cmd_reset "$@" ;;
    migrate|up) cmd_migrate "$@" ;;
    env:print) cmd_env_print "$@" ;;
    pull-prod-data) cmd_pull_prod_data "$@" ;;
    types:local) cmd_types_local "$@" ;;
    -h|--help|help|"") usage ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
