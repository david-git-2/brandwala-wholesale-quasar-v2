---
name: Supabase backup restore
overview: Add a scheduled GitHub Actions workflow that dumps linked Supabase Postgres (roles, schema, public data, auth tables), encrypts the archive with GPG, and stores it as a 30-day artifact; plus a `restore.sh` operator script and `docs/BACKUP-RESTORE.md` runbook aligned with Postgres 17 and existing local dump conventions.
todos:
  - id: workflow-backup
    content: Create .github/workflows/supabase-backup.yml (PG17 client, 4 dumps, sanity, tar, GPG, artifact 30d, secrets comment)
    status: pending
  - id: restore-script
    content: Create scripts/restore.sh (RESTORE gate, decrypt/extract, ordered psql + replica role, verification counts)
    status: pending
  - id: runbook
    content: Create docs/BACKUP-RESTORE.md (artifact download, test throwaway restore first, prod checklist, limitations)
    status: pending
  - id: lint-verify
    content: Run actionlint on workflow and shellcheck on restore.sh
    status: pending
isProject: false
---

# Supabase self-hosted backup + restore

## Context from this repo

| Fact | Source |
|------|--------|
| Hosted Postgres **major version 17** | [`supabase/config.toml`](supabase/config.toml) `major_version = 17` |
| Existing prod→local dump flow (roles, schema, split public/auth data) | [`scripts/supabase-local.sh`](scripts/supabase-local.sh) `cmd_pull_prod_data` |
| pg_dump 17 `\restrict` / `\unrestrict` lines should be stripped before `psql` | `sanitize_dump_file` in same file |
| No existing `actionlint` / `shellcheck` CI job | Run locally once after implementation |

Pin **postgresql-client-17** in the workflow (PGDG apt on `ubuntu-latest`), not `latest` or generic `postgresql-client`.

Secrets (document in workflow header + runbook):

- `SUPABASE_DB_URL` — Session pooler or direct `5432` URL (`sslmode=require`); **not** transaction pooler `6543`.
- `BACKUP_PASSPHRASE` — symmetric GPG passphrase for artifacts.

```bash
gh secret set SUPABASE_DB_URL --repo OWNER/REPO
gh secret set BACKUP_PASSPHRASE --repo OWNER/REPO
```

---

## Phase 1 — GitHub Actions backup workflow

**Goal:** Daily encrypted backup artifact; manual re-run via `workflow_dispatch`.

**Files:** create [`.github/workflows/supabase-backup.yml`](.github/workflows/supabase-backup.yml)

**Change:**

1. **Triggers & permissions** (per spec):
   - `schedule`: `cron: '0 3 * * *'` (03:00 UTC)
   - `workflow_dispatch`
   - `permissions: contents: read` (no `checkout` required unless you want a repo pin — dumps use only secrets + client tools)

2. **Install client** — one step adding PGDG repo and `postgresql-client-17`; verify `pg_dump --version` shows 17.x.

3. **Shared exclusion list** — bash array expanded to repeated flags for both schema and data dumps:

   `supabase_migrations`, `extensions`, `graphql`, `graphql_public`, `realtime`, `vault`, `pgbouncer`, `storage`, `auth`

4. **Dump sequence** (all via `pg_dump "$SUPABASE_DB_URL"` with `--no-owner --no-privileges`):

   | File | Flags |
   |------|--------|
   | `roles.sql` | `--role-only` |
   | `schema.sql` | `--schema-only` + exclusions above |
   | `data.sql` | `--data-only --use-copy` + same exclusions |
   | `auth.sql` | `--data-only --use-copy` `-t auth.users -t auth.identities -t auth.refresh_tokens -t auth.sessions` |

5. **Sanity checks** (fail job):
   - Any of the four files missing or **0 bytes**
   - `data.sql` has no `INSERT` / `COPY` (e.g. `grep -qE '^(COPY |INSERT INTO )' data.sql`)

6. **Package & encrypt**
   - `STAMP=$(date -u +%Y%m%d-%H%M)`
   - `tar czf "supabase-backup-${STAMP}.tar.gz" roles.sql schema.sql data.sql auth.sql`
   - `gpg --batch --yes --passphrase-fd 0 -c -o "supabase-backup-${STAMP}.tar.gz.gpg" "supabase-backup-${STAMP}.tar.gz"` with passphrase from env (never `echo` passphrase; use `<<<` or fd from secret env)
   - Remove unencrypted `.tar.gz` and `.sql` files before upload

7. **Artifact** — `actions/upload-artifact@v4` with `retention-days: 30`, name e.g. `supabase-backup-${STAMP}`

8. **Top comment block** — required secrets, pooler warning, storage files out of scope (TODO: re-upload blobs from S3/Cloudinary)

```mermaid
flowchart LR
  cron[Cron_or_dispatch] --> pg17[postgresql-client-17]
  pg17 --> dumps[roles_schema_data_auth]
  dumps --> check[Sanity_checks]
  check --> tar[tar.gz]
  tar --> gpg[GPG_symmetric]
  gpg --> artifact[GH_Artifact_30d]
```

---

## Phase 2 — `scripts/restore.sh`

**Goal:** Operator-driven decrypt → restore → verification; safe confirmation gate.

**Files:** create [`scripts/restore.sh`](scripts/restore.sh) (executable `chmod +x`)

**Change:**

1. **Shell** — `#!/usr/bin/env bash`, `set -euo pipefail`; require env: `TARGET_DB_URL`, `BACKUP_FILE` (`.tar.gz.gpg`), `BACKUP_PASSPHRASE`.

2. **Pre-flight**
   - Validate files/vars exist
   - Print target host/db parsed from URL (redact password) and backup filename
   - Prompt: type **`RESTORE`** to continue (else exit 1)

3. **Decrypt & extract** — `mktemp -d`; `gpg --batch --yes --passphrase-fd 0 -d`; `tar xzf`; assert four SQL files present

4. **Optional strip** (reuse local convention) — for each `*.sql`, remove lines matching `^\restrict ` / `^\unrestrict ` (pg_dump 17) before `psql`

5. **Restore order**
   - **roles.sql:** `psql "$TARGET_DB_URL" -v ON_ERROR_STOP=0 -f roles.sql` (tolerate “already exists”)
   - **schema.sql:** `ON_ERROR_STOP=1`
   - **data.sql** and **auth.sql:** each run as:
     ```bash
     psql "$TARGET_DB_URL" -v ON_ERROR_STOP=1 \
       -c 'SET session_replication_role = replica' \
       -f "$file"
     psql "$TARGET_DB_URL" -v ON_ERROR_STOP=1 \
       -c 'SET session_replication_role = DEFAULT'
     ```
     (If a single session is preferred for huge files, use `-f` with a small wrapper SQL that sets replica, `\i file`, then `DEFAULT` — same semantics.)

6. **Verification** — dynamic “top 5” public tables by `pg_stat_user_tables.n_live_tup` (fallback `reltuples` if stats empty), then `SELECT count(*) FROM public.<table>` for each; plus `SELECT count(*) FROM auth.users;`. Print labeled output for manual compare to source.

7. **Cleanup** — trap `rm -rf` on temp dir

**Note:** Hosted restore can still hit object conflicts on a non-empty `public` schema; the runbook (Phase 3) will say **test on a new throwaway project** first and treat schema errors as a signal to use a fresh project or trim conflicts — out of scope to auto-fix beyond the user’s restore order.

---

## Phase 3 — Runbook

**Goal:** Test-restore-first procedure; prod disaster steps; limitations.

**Files:** create [`docs/BACKUP-RESTORE.md`](docs/BACKUP-RESTORE.md)

**Change (sections):**

1. **What is backed up** — `public` schema+data, selected `auth` tables, roles; **not** storage object blobs (TODO in runbook: re-upload files; metadata in `storage` schema intentionally excluded from dumps per workflow)

2. **Download artifact** — GitHub UI (Actions → run → Artifacts) and `gh run list` / `gh run download <run-id> -n <artifact-name>`

3. **Test restore (required before prod)** — ordered steps:
   - Create new Supabase project (throwaway)
   - Session pooler connection string as `TARGET_DB_URL`
   - Export `BACKUP_PASSPHRASE` locally (never commit)
   - Run `./scripts/restore.sh`
   - Compare verification counts to last known good / production read-only query

4. **Prod restore** — same script, production `TARGET_DB_URL` after successful test; **post-restore checklist:**
   - Rotate DB password in Supabase dashboard
   - Re-apply repo migrations / dashboard steps for storage buckets, edge functions, RLS or objects not in schema dump
   - Re-upload storage files (explicitly out of scope)
   - Smoke-test auth (Google OAuth) for at least one real user

5. **Known limitations** — no PITR; backup contains password hashes (treat `.gpg` as highly sensitive); 30-day artifact retention → monthly off-site copy if longer retention needed; Free plan has no Supabase-managed backups

Optional one-line link from [`docs/README.md`](docs/README.md) “I want to know” table → `BACKUP-RESTORE.md` (only if you want discoverability; not in your deliverable list).

---

## Phase 4 — Acceptance checks (after implement)

**Goal:** `actionlint` + `shellcheck` clean.

**Commands** (operator/agent after files exist):

```bash
actionlint .github/workflows/supabase-backup.yml
shellcheck scripts/restore.sh
```

If `actionlint` is not installed locally: `brew install actionlint` or `go install github.com/rhysd/actionlint/cmd/actionlint@latest`.

No secrets in repo; workflow uses `${{ secrets.* }}` only at runtime.

---

## Relationship to existing `backend:pull-prod-data`

| | CI backup (new) | Local dev (`pnpm run backend:pull-prod-data`) |
|--|-----------------|-----------------------------------------------|
| Purpose | Disaster recovery artifact | Dev DB seed from prod |
| Auth tables | 4 named tables | Broader auth dump minus drift tables |
| Storage | Excluded | N/A (local never copies blobs) |
| Restore | `restore.sh` → hosted | Migrations reset + compat rewrite → Docker |

Keep both; do not change `supabase-local.sh` unless a later task asks to align dumps.
