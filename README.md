# BrandWala Wholesale Quasar

BrandWala Wholesale Quasar is a Quasar-based business platform for managing wholesale and commerce operations in one place.

## What this project offers

The app brings together the core workflows needed to run a multi-role wholesale business:

- role-based login for superadmin, admin, staff, viewer, and customer access
- dashboards for different user types
- product, store, inventory, and market management
- invoices, orders, shipments, and billing workflows
- costing and product-based costing tools
- commerce and shop views for customer-facing access
- Supabase-backed data, authentication, and permissions

## Main areas

- `Platform` for superadmin administration
- `App` for internal business operations
- `Shop` for customer-side browsing and purchasing flows

## Tech stack

- Frontend: Quasar SPA
- Backend: Supabase
- Authentication: Google OAuth through Supabase
- Deployment: Cloudflare Pages for the frontend

## Project structure

- `web/` frontend application
- `supabase/` database migrations, local config, and generated types

## High-level auth model

The app uses scoped login flows and membership-based access control:

- `platform` for superadmin access
- `app` for admin, staff, and viewer access
- `shop` for customer access

Access is determined by email, role, active membership status, and tenant/customer group rules.

## Deployment notes

For Cloudflare Pages:

- root directory: `web`
- build command: `pnpm install && pnpm run build`
- build output directory: `dist/spa`

Common environment variables:

- `NODE_VERSION=22`
- `SKIP_DEPENDENCY_INSTALL=true`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_SUPABASE_URL`
- `VITE_LOCAL_APP_URL`
- `VITE_PRODUCTION_APP_URL`
- `VITE_CLOUDINARY_CLOUD_NAME`
- `VITE_CLOUDINARY_UPLOAD_PRESET`

## Local development

### Frontend only

- `pnpm run dev`
- `pnpm run build`
- `pnpm run lint`

### Local Supabase (Docker) — keep production safe

Day-to-day schema/RPC work should hit **local Docker**, not the linked remote. Production remains the target only for intentional `pnpm run deploy:backend`.

**Prerequisites:** Docker Desktop running; repo Supabase CLI (`pnpm install` at root); project already linkable (`pnpm run backend:login` + `pnpm run backend:link`).

**One-time setup**

1. Add Google OAuth to `web/.env.profile.prod` (same client as hosted Auth): `GOOGLE_CLIENT_ID` + `GOOGLE_CLIENT_SECRET` from Dashboard → Authentication → Providers → Google. (`backend:start` loads these from `web/.env.profile.prod` / legacy `web/.env.prod` / `web/.env` automatically.)
2. In Google Cloud Console, add authorized redirect URI: `http://127.0.0.1:54321/auth/v1/callback` (and `http://localhost:54321/auth/v1/callback` if you use localhost).
3. Start the stack: `pnpm run backend:start`
4. Save Quasar env profiles (gitignored):
   - Prod once: `cp web/.env web/.env.profile.prod` (while still on cloud keys), then ensure the `GOOGLE_*` lines above are present in that file.
   - Local once: `pnpm run backend:env:print > web/.env.profile.local`, then add Cloudinary/CF vars from [`web/.env.local.example`](web/.env.local.example) or from `web/.env.profile.prod`.
   - Never use `web/.env.local` as a profile store — Vite auto-loads that name and it overrides `web/.env` (breaks `env:prod`).
5. Switch anytime: `pnpm run env:local` or `pnpm run env:prod` (then restart `pnpm run dev`). Check with `pnpm run env:status`.
6. Optional — clone prod **rows** into local (overwrites local DB; Storage blobs are not copied): `pnpm run backend:pull-prod-data` (type `yes`, or `pnpm run backend:pull-prod-data -- --force`). Dumps go to gitignored `supabase/.dumps/`. Requires `psql` on your PATH. After a data pull, the same Google accounts can sign in locally because `auth.users` / identities come from prod **and** local uses the same Google OAuth client.

**Daily local loop**

1. `pnpm run backend:start` (if stopped)
2. `pnpm run env:local` and restart `pnpm run dev`
3. **Test migrations only (fast):** `pnpm run backend:reset` — replays all migrations, no prod dump. Fix until green.
4. **Then** load prod rows once: `pnpm run backend:pull-prod-data`
5. New feature migrations: edit SQL → `pnpm run backend:local` (or `pnpm run backend:reset` for a clean replay) → when ready `pnpm run deploy:backend`

**Useful scripts**

| Script | Purpose |
|--------|---------|
| `env:local` / `env:prod` / `env:status` | Switch Quasar `web/.env` between Docker and cloud |
| `backend:start` / `backend:stop` / `backend:status` | Docker stack lifecycle |
| `backend:env:print` | Local URL + anon/service keys (seed `web/.env.profile.local`) |
| `backend:reset` | Rebuild local DB from migrations only (empty business data) |
| `backend:local` | Apply pending migrations to local (`migration up --include-all`) |
| `backend:pull-prod-data` | Opt-in dump linked prod → restore data into local |
| `backend:types:local` | Generate types from local DB |
| `deploy:backend` | Push migrations to **linked production** + regenerate types |
| `deploy:frontend` | Switches to `env:prod`, builds, deploys to Cloudflare Pages |

Do not run experimental SQL against the linked remote while iterating locally.

For the **combined platform reference** (feature matrix, all module details, permissions, redesign entities), see **[doc/MASTER_PLAN.md](doc/MASTER_PLAN.md)** §14–§18.

Other docs: `doc/` (domain specs), `docs/` (UI + AI workflow).

## Database Optimization (Reclaiming Space)

If your database size grows due to expired product sync snapshots, you can optimize it by running the following SQL queries in the Supabase Dashboard SQL Editor:

```sql
-- 1. Delete all expired snapshots (older than 7 days)
DELETE FROM public.product_sync_snapshots 
WHERE expires_at < now();

-- 2. Immediately reclaim the disk space back to the OS
VACUUM FULL public.product_sync_snapshots;
```

Alternatively, you can execute the deletion using the Supabase CLI in your terminal:

```bash
# Delete all expired snapshots
pnpm exec supabase db query --linked "DELETE FROM public.product_sync_snapshots WHERE expires_at < now();"
```

> [!IMPORTANT]
> **Reclaiming space (VACUUM):** The Supabase CLI `db query` command wraps executions in a transaction block, which will cause `VACUUM FULL` to fail with `ERROR: 25001: VACUUM cannot run inside a transaction block`. Always run the `VACUUM FULL` query directly in the **Supabase Dashboard SQL Editor** instead of the CLI.


